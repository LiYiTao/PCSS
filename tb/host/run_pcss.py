import os
import socket
import time
import struct
import sys

class Transmitter(object):
    def __init__(self):
        self.socket_inst = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket_inst.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    def connect_lwip(self, ip_address):
        self.socket_inst.connect(ip_address)

    def close(self):
        self.socket_inst.close()
        
    def send_flit_bin(self, flit_bin_file, data_type):
        '''
        发送flit
        '''
        with open(flit_bin_file, 'rb') as file:
            flit_bin = file.read()
        length = len(flit_bin) >> 2
        if length > 2**26:
            print("===<2>=== %s is larger than 0.25GB" % flit_bin_file)
            print("===<2>=== send flit length failed")
            return 0
        send_bytes = bytearray()
        send_bytes += struct.pack('I', length)
        send_bytes += struct.pack('I', data_type)
        send_bytes += flit_bin
        #self.socket_inst.sendall(struct.pack('I', length))
        #ack = self.socket_inst.recv(1024)
        #if (ack == b'done'):
        #    print("===<2>=== send flit length succeed")
        #self.socket_inst.sendall(flit_bin)
        self.socket_inst.sendall(send_bytes)
        return 1

    def send_flit(self, flit_file, directions=0):
        '''
        发送flit
        '''
        with open(flit_file, 'r') as file:
                flit_list = file.readlines()
        length = len(flit_list)
        if length > 2**26:
            print("===<2>=== %s is larger than 0.25GB" % flit_file)
            print("===<2>=== send flit length failed")
            return 0
        print("===<2>=== send flit length succeed")
        #self.socket_inst.sendall(struct.pack('I', length))
        #ack = self.socket_inst.recv(1024)
        #if (ack == b'done'):
        
        j = 0
        while(j < length):
            send_bytes = bytearray()
            send_bytes += struct.pack('Q', length)
            # send_bytes += struct.pack('I', 0x8000) # TODO tik
            for i in range(j,min(j + 16777216 * 4,length)):
                send_bytes += struct.pack('Q', int(flit_list[i % length].strip(),16))
            self.socket_inst.sendall(send_bytes)
            j = j + 16777216 * 4
            if (j <= length):
                reply = self.socket_inst.recv(1024)
                print("%s" % reply)
        return 1    

def run_pcss(tc="", pre="", recv = True, ip = "10.11.8.238", port=1): # 10.11.8.238
    if tc != "" :
        if os.path.exists(tc):
            tc  = tc+"\\"
        else:
            tc = ""
    trans = Transmitter()
    ip_address = (ip, port) #TODO port
    trans.connect_lwip(ip_address)
    print("===<2>=== tcp connect succeed")
    start_time = time.time_ns()
    res=trans.send_flit(tc+pre+"config.txt") #TODO send file
    if res == 0:
        return
    end_time = time.time_ns()
    print("===<2>=== send flit data   succeed")
    print('===<2>=== tcp sent elapsed : %.3f ms' % ((end_time - start_time)/1000000))

    f = open(tc+"recv_"+pre+"flitout.txt", "wb")
    # fbin = open(tc+"recv_"+pre+"flitout.bin", "wb")
    start_time = time.time_ns()
    hl = b""
    index = 0
    tot = 0
    while recv:
        request = trans.socket_inst.recv(1024)
        if len(request) <= 0:
            break
        # fbin.write(request)
        for i in range(len(request)):
            b = b"%02x" % request[i]
            hl = b + hl
            index = index + 1
            if (index == 8):
                f.write (hl + b"\n")
                # print(hl)
                hl = b""
                index = 0
                tot = tot + 1
    end_time = time.time_ns()
    f.close()
    # fbin.close()
    trans.socket_inst.close()
    print('===<2>=== tcp recv elapsed : %.3f ms with %d flits' % ((end_time - start_time)/1000000,tot))

if __name__ == "__main__":
    id = 0
    if len(sys.argv)>1:
        id = int(sys.argv[1])
    stime = time.time_ns()
    run_pcss("D:", port=id)
    etime = time.time_ns()
    print("\n<--total time elapsed : %.3f ms-->\n" % ((etime - stime)/1000000.0))
