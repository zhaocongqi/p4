# This is neeeded to execure "run_pd_rpc"
from ipaddress import ip_address
p4 = bfrt.simple_l3_mirror2.pipe

NextSeq = p4.Ingress.NextSeq
Flag = p4.Ingress.Flag
flag = p4.Ingress.flag
nextseq = p4.Ingress.nextseq

# NextSeq.clear()
# Flag.clear()

# NextSeq.dump(table=True,from_hw=True)
# Flag.dump(table=True,from_hw=True)

NextSeq.get(from_hw=True,REGISTER_INDEX=0)
Flag.get(from_hw=True,REGISTER_INDEX=0)
nextseq.get(from_hw=True,REGISTER_INDEX=0)
flag.get(from_hw=True,REGISTER_INDEX=0)
