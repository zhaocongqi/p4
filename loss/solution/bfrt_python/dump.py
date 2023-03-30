# This is neeeded to execure "run_pd_rpc"
from ipaddress import ip_address
p4 = bfrt.loss.pipe

NextSeq = p4.Ingress.NextSeq
Loss = p4.Ingress.Loss
Reorder = p4.Ingress.Reorder

NextSeq.clear()
Loss.clear()
Reorder.clear()

NextSeq.get(from_hw=True,REGISTER_INDEX=0)
Loss.get(from_hw=True,REGISTER_INDEX=0)
Reorder.get(from_hw=True,REGISTER_INDEX=0)