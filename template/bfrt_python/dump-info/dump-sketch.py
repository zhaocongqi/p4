from ipaddress import ip_address

import sys
import time
import json
import signal

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

# Sketch
sketch = p4.Ingress.sketch

for table in sketch.info(return_info=True, print_info=False):
    if table['type'] in ['REGISTER']:
        if table['full_name'].split('.')[3].rstrip('0123456789') in ['sketch_count']:
            table['node'].dump(table=True,from_hw=True)
        if table['full_name'].split('.')[3].rstrip('0123456789') in ['sketch_delay']:
            table['node'].dump(table=True,from_hw=True)
        if table['full_name'].split('.')[3].rstrip('0123456789') in ['sketch_max_delay']:
            table['node'].dump(table=True,from_hw=True)
        if table['full_name'].split('.')[3].rstrip('0123456789') in ['sketch_min_delay']:
            table['node'].dump(table=True,from_hw=True)