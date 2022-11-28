import os
import sys
import json
import struct
import random

f = open("dat.json")
file_write_obj = open("dat-delay.json", 'w')
line = f.readline()
map = {}
while line:
    s = json.loads(line)
    SrcIP = s["SrcIP"]
    DstIP = s["DstIP"]
    SrcPort = s["SrcPort"]
    DstPort = s["DstPort"]
    Protocol = s["Protocol"]
    key = str(SrcIP) + str(DstIP) + str(SrcPort) + str(DstPort) + str(Protocol)
    # print(SrcIP,DstIP,Protocol,SrcPort,DstPort)
    # 0.1ms-6ms
    if key in map.keys(): 
        delay = map[key]
        delt = random.randint(-3,3)
        delay = delay + delt
        dict_val = {'SrcIP':SrcIP,'DstIP':DstIP,'Protocol':Protocol,'SrcPort':SrcPort,'DstPort':DstPort,'Delay':delay}
    else:
        delay1 = random.randint(10,20)
        delay2 = random.randint(40,120)
        rand = random.randint(1,10)
        if rand == 1 or rand == 2:
            map[key] = delay2
        else:
            map[key] = delay1
        dict_val = {'SrcIP':SrcIP,'DstIP':DstIP,'Protocol':Protocol,'SrcPort':SrcPort,'DstPort':DstPort,'Delay':map[key]}
    json_val = json.dumps(dict_val)
    print(json_val)
    file_write_obj.writelines(json_val)
    file_write_obj.write('\n')
    line = f.readline()
f.close()
file_write_obj.close()