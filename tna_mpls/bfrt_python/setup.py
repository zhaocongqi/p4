from ipaddress import ip_address

p4 = bfrt.mpls.pipe

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

ipv4_host = p4.Ingress.ipv4_host
ipv4_host.add_with_send(dst_addr=ip_address('10.0.0.2'),   port=130)
ipv4_host.add_with_send(dst_addr=ip_address('10.0.0.1'),   port=129)

bfrt.complete_operations()

# Final programming
print("""
******************* PROGAMMING RESULTS *****************
""")
print ("Table ipv4_host:")
ipv4_host.dump(table=True)