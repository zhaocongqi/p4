from ipaddress import ip_address

import sys
import time
import json
import signal
sys.path.append('/usr/local/lib/python3.5/dist-packages')
import redis

p4 = bfrt.cm_sketch.pipe

# This function can clear all the tables and later on other fixed objects
# once bfrt support is added.
def clear_all(verbose=True, batching=True):
    global p4
    global bfrt
    
    def _clear(table, verbose=False, batching=False):
        if verbose:
            print("Clearing table {:<40} ... ".
                  format(table['full_name']), end='', flush=True)
        try:    
            entries = table['node'].get(regex=True, print_ents=False)
            try:
                if batching:
                    bfrt.batch_begin()
                for entry in entries:
                    entry.remove()
            except Exception as e:
                print("Problem clearing table {}: {}".format(
                    table['name'], e.sts))
            finally:
                if batching:
                    bfrt.batch_end()
        except Exception as e:
            if e.sts == 6:
                if verbose:
                    print('(Empty) ', end='')
        finally:
            if verbose:
                print('Done')

        # Optionally reset the default action, but not all tables
        # have that
        try:
            table['node'].reset_default()
        except:
            pass
    
    # The order is important. We do want to clear from the top, i.e.
    # delete objects that use other objects, e.g. table entries use
    # selector groups and selector groups use action profile members
    

    # Clear Match Tables
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR']:
            _clear(table, verbose=verbose, batching=batching)

    # Clear Selectors
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['SELECTOR']:
            _clear(table, verbose=verbose, batching=batching)
            
    # Clear Action Profiles
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['ACTION_PROFILE']:
            _clear(table, verbose=verbose, batching=batching)
    
#clear_all()

def pasermetadata(info,sketch):
    d1 = dict()
    for x in json.loads(info):
        index = x[u'key'][u'$REGISTER_INDEX']
        data = x[u'data'][sketch][1]
        d1[index] = data
    return d1

# Sketch
sketch = p4.Ingress.sketch

# Redis Connection
# pool = redis.ConnectionPool(host='localhost', port=6379)
# r = redis.Redis(connection_pool=pool)
r1 = redis.Redis(host='localhost',port=6379,db=0)
r2 = redis.Redis(host='localhost',port=6379,db=1)

# Set Redis
def setRedis(mydict,r):
    for key in mydict:
        r.set(key, json.dumps(mydict[key]))

# Handle Sketch
count_dict = dict()
delay_dict = dict()
max_delay_dict = dict()
min_delay_dict = dict()

t = time.perf_counter()
for table in sketch.info(return_info=True, print_info=False):
    if table['type'] in ['REGISTER']:
        key = table['full_name'].split('.')[3]
        if key.rstrip('0123456789') in ['sketch_count']:
            info = table['node'].dump(json=True,return_ents=True,from_hw=True)
            value = pasermetadata(info,'Ingress.sketch.' + key +'.f1')
            count_dict[key] = value
        if key.rstrip('0123456789') in ['sketch_delay']:
            info = table['node'].dump(json=True,return_ents=True,from_hw=True)
            value = pasermetadata(info,'Ingress.sketch.' + key +'.f1')
            delay_dict[key] = value
        if key.rstrip('0123456789') in ['sketch_max_delay']:
            info = table['node'].dump(json=True,return_ents=True,from_hw=True)
            value = pasermetadata(info,'Ingress.sketch.' + key +'.f1')
            max_delay_dict[key] = value
        if key.rstrip('0123456789') in ['sketch_min_delay']:
            info = table['node'].dump(json=True,return_ents=True,from_hw=True)
            value = pasermetadata(info,'Ingress.sketch.' + key +'.f1')
            min_delay_dict[key] = value
print("Sketch获取耗时: ")
print(time.perf_counter() - t)

# Clear Sketch
for table in sketch.info(return_info=True, print_info=False):
    if table['type'] in ['REGISTER']:
        table['node'].clear()

# Set to Redis
setRedis(count_dict,r1)
setRedis(delay_dict,r1)
setRedis(max_delay_dict,r1)
setRedis(min_delay_dict,r1)

# Get Delay Info
SKETCH_BUCKET_LENGTH_WIDTH = 10
SKETCH_BUCKET_LENGTH = (1 << SKETCH_BUCKET_LENGTH_WIDTH) - 1

flows = []

f = open("/root/zcq/tna_cm-sketch/bfrt_python/dat-hash.json")
line = f.readline()
while line:
    result = dict()
    s = json.loads(line)
    result['SrcIP'] = s["SrcIP"]
    result['DstIP'] = s["DstIP"]
    result['SrcPort'] = s["SrcPort"]
    result['DstPort'] = s["DstPort"]
    result['Protocol'] = s["Protocol"]
    HASH1 = s["HASH1"]
    HASH2 = s["HASH2"]
    HASH3 = s["HASH3"]
    # print(SrcIP,DstIP,Protocol,SrcPort,DstPort)

    index1 = int(HASH1.encode("utf-8"),16) & SKETCH_BUCKET_LENGTH
    index2 = int(HASH2.encode("utf-8"),16) & SKETCH_BUCKET_LENGTH
    index3 = int(HASH3.encode("utf-8"),16) & SKETCH_BUCKET_LENGTH

    count1 = count_dict['sketch_count1'][index1]
    count2 = count_dict['sketch_count2'][index2]
    count3 = count_dict['sketch_count3'][index3]  
    min_count = min([count1,count2,count3])

    delay1 = delay_dict['sketch_delay1'][index1]
    delay2 = delay_dict['sketch_delay2'][index2]
    delay3 = delay_dict['sketch_delay3'][index3]  
    min_delay = min([delay1,delay2,delay3])

    max_delay1 = max_delay_dict['sketch_max_delay1'][index1]
    max_delay2 = max_delay_dict['sketch_max_delay2'][index2]
    max_delay3 = max_delay_dict['sketch_max_delay3'][index3]  
    min_max_delay = min([max_delay1,max_delay2,max_delay3])

    min_delay1 = min_delay_dict['sketch_min_delay1'][index1]
    min_delay2 = min_delay_dict['sketch_min_delay2'][index2]
    min_delay3 = min_delay_dict['sketch_min_delay3'][index3]  
    max_min_delay = max([min_delay1,min_delay2,min_delay3])

    result['count'] = min_count
    result['delay'] = min_delay
    result['max_delay'] = min_max_delay
    result['min_delay'] = max_min_delay

    avg_delay = 0
    if(min_count != 0):
        avg_delay = min_delay/min_count
    result['avg_delay'] = avg_delay

    # print(result)
    flows.append(result)

    # line = ''
    line = f.readline()
f.close()

for flow in flows:
    key = flow['SrcIP'] + ':' + str(flow['SrcPort']) + '->' + flow['DstIP'] + ':' + str(flow['DstPort'])
    d1 = dict()
    d1['count'] = flow['count']
    d1['delay'] = flow['delay']
    d1['max_delay'] = flow['max_delay']
    d1['min_delay'] = flow['min_delay']
    d1['avg_delay'] = flow['avg_delay']
    r2.set(key, json.dumps(d1))