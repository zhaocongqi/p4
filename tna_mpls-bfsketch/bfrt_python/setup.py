from ipaddress import ip_address
import sys
import time
import json
import signal
sys.path.append('/usr/local/lib/python3.5/dist-packages')
import redis
import schedule

p4 = bfrt.main.pipe
redis_cli = redis.Redis(host='localhost',port=6379,db=15)

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
    
# Route Set
def simple_fwd():
    p4.Ingress.simple_fwd.clear()
    p4.Ingress.simple_fwd.add_with_hit(ingress_port=130,port=131)
    p4.Ingress.simple_fwd.add_with_hit(ingress_port=131,port=130)
    p4.Ingress.simple_fwd.add_with_hit(ingress_port=128,port=129)
    p4.Ingress.simple_fwd.add_with_hit(ingress_port=129,port=128)
    p4.Egress.tbl_mask.clear()
    p4.Egress.tbl_mask.add_with_set_mask(egress_port=128,mask=0x0001FFFF)
    p4.Egress.tbl_mask.add_with_set_mask(egress_port=129,mask=0x0001FFFF)
    p4.Egress.tbl_mask.add_with_set_mask(egress_port=130,mask=0x0001FFFF)
    p4.Egress.tbl_mask.add_with_set_mask(egress_port=131,mask=0x0001FFFF)

# Set Redis and Clear Sketch and Bloomfilter
def set_redis():
    global time
    global redis_cli
    print("--- 5 SECONDS ---")
    t = time.perf_counter()
    for table in p4.Egress.bf_sketch.info(return_info=True, print_info=False):
        if table['type'] in ['REGISTER']:
            key = table['full_name'].split('.')[3]
            value = table['node'].dump(json=True,return_ents=True,from_hw=True)
            redis_cli.set(key, value)
    print("Sketch获取耗时: ")
    print(time.perf_counter() - t)
    for table in p4.Egress.bf_sketch.info(return_info=True, print_info=False):
        if table['type'] in ['REGISTER']:
            table['node'].clear()

simple_fwd()
set_redis()
# schedule.every(5).seconds.do(set_redis)
# time.sleep(5)
# schedule.run_pending()
# while True:
#     try:
#         schedule.run_pending()
#     except:
#         break