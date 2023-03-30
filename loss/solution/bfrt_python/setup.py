# This is neeeded to execure "run_pd_rpc"
from ipaddress import ip_address
p4 = bfrt.loss.pipe

# This function can clear all the tables and later on other fixed objects
# once bfrt support is added.
def clear_all():
    global p4

    # The order is important. We do want to clear from the top, i.e.
    # delete objects that use other objects, e.g. table entries use
    # selector groups and selector groups use action profile members
    
    # Clear Match Tables
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR']: 
            print("Clearing table {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
    # Clear Selectors
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['SELECTOR']:
            print("Clearing ActionSelector {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
    # Clear Action Profiles
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['ACTION_PROFILE']:
            print("Clearing ActionProfile {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
    
clear_all()

# simple_fwd
simple_fwd = p4.Ingress.simple_fwd
simple_fwd.add_with_send(ingress_port=128,port=129)
simple_fwd.add_with_send(ingress_port=129,port=128)