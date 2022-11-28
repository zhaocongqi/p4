import numpy as np
import binascii
import socket
import struct
import json

file_write_obj = open("dat.json", 'w')
MyType=np.dtype({
    'names':['srcIP','srcPort','dstIP','dstPort','protocol'],
    'formats':['I','H','I','H','B']
})
myarray = np.fromfile("./0.dat",dtype=MyType)
print("len(myarray)::", myarray.size)
# print(type(myarray[0]['srcIP']))
# ip = socket.inet_ntoa(myarray[0]['srcIP'])
# print(ip)
for item in myarray:
    SrcIP = socket.inet_ntoa(item['srcIP'])
    DstIP = socket.inet_ntoa(item['dstIP'])
    SrcPort = int(item['srcPort'])
    DstPort = int(item['dstPort'])
    Protocol = int(item['protocol'])
    dict_val = {'SrcIP':SrcIP,'DstIP':DstIP,'Protocol':Protocol,'SrcPort':SrcPort,'DstPort':DstPort}
    json_val = json.dumps(dict_val)
    # print(json_val)
    file_write_obj.writelines(json_val)
    file_write_obj.write('\n')

file_write_obj.close()