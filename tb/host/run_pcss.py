import os
import socket
import time
import struct

class Transmitter(object):
    def __init__(self):
        self.socket_inst = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket_inst.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    def connect_lwip(self, ip_address):
        self.socket_inst.connect(ip_address)

    def close(self):
        self.socket_inst.close()
        
    def send_flit_bin(self, flit_bin_file):
        '''
        发送flit
        '''
        with open(flit_bin_file, 'rb') as file:
            flit_bin = file.read()
        length = len(flit_bin) >> 2
        if length > 2**26:
            print("===<2>=== %s is larger than 0.5GB" % flit_bin_file)
            print("===<2>=== send flit length failed")
            return 0
        self.socket_inst.sendall(struct.pack('I', length))
        ack = self.socket_inst.recv(1024)
        if (ack == b'done'):
            print("===<2>=== send flit length succeed")
        self.socket_inst.sendall(flit_bin)
        return 1

    def send_flit(self, flit_file):
        '''
        发送flit
        '''
        with open(flit_file, 'r') as file:
                flit_list = file.readlines()
        length = len(flit_list)
        if length > 2**26:
            print("===<2>=== %s is larger than 0.5GB" % flit_file)
            print("===<2>=== send flit length failed")
            return 0
        self.socket_inst.sendall(struct.pack('I', length))
        ack = self.socket_inst.recv(1024)
        if (ack == b'done'):
            print("===<2>=== send flit length succeed")
        j = 0
        while(j < length):
            send_bytes = bytearray()
            for i in range(j,min(j + 16777216 * 4,length)):
                send_bytes += struct.pack('Q', int(flit_list[i % length].strip(),16))
            self.socket_inst.sendall(send_bytes)
            j = j + 16777216 * 4
            if (j <= length):
                reply = self.socket_inst.recv(1024)
                print("%s" % reply)
        return 1    

def run_pcss(tc="", pre="", recv = True, ip = "10.11.8.238"):
    if tc != "" :
        if os.path.exists(tc):
            tc  = tc+"\\"
        else:
            tc = ""
    trans = Transmitter()
    ip_address = (ip,1) #TODO port
    trans.connect_lwip(ip_address)
    print("===<2>=== tcp connect succeed")
    start_time = time.time_ns()
    res=trans.send_flit(tc+pre+"config.txt") #TODO send file
    if res == 0:
        return
    end_time = time.time_ns()
    print("===<2>=== send flit data   succeed")
    print('===<2>=== tcp sent elapsed : %.3f ms' % ((end_time - start_time)/1000000))

    f = open(tc+"recv_"+pre+"flitout.txt", "w")
    fbin = open(tc+"recv_"+pre+"flitout.bin", "wb")
    start_time = time.time_ns()
    hl = ""
    index = 0
    tot = 0
    while recv:
        request = trans.socket_inst.recv(1024)
        if len(request) <= 0:
            break
        fbin.write(request)
        for i in range(len(request)):
            b = "%02x" % request[i]
            hl = b + hl
            index = index + 1
            if (index == 4):
                f.write (hl + '\n')
                # print(hl)
                hl = ""
                index = 0
                tot = tot + 1         
    end_time = time.time_ns()
    f.close()
    fbin.close()
    trans.socket_inst.close()
    print('===<2>=== tcp recv elapsed : %.3f ms with %d flits' % ((end_time - start_time)/1000000,tot))

if __name__ == "__main__":
    stime = time.time_ns()
    run_pcss("D:")
    etime = time.time_ns()
    print("\n<--total time elapsed : %.3f ms-->\n" % ((etime - stime)/1000000.0))
