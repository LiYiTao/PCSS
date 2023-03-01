import socket
import sys
import struct
import os
import time
import mmap
import fcntl
import threading

s1 = threading.Semaphore(1)
receive_count : int = 0
active_ip = ""

CHIP_RESET = 10

is_A9=os.system("lscpu | grep 'Model name' | awk '{print $NF}' | grep 'Cortex-A9$' > /dev/null")
if is_A9 == 0:
    FINISH_XFER = ord('a') + (ord('a') << 8) + (4 << 16) + (1 << 30)
    START_XFER  = ord('b') + (ord('a') << 8) + (4 << 16) + (1 << 30)
    XFER        = ord('c') + (ord('a') << 8) + (4 << 16) + (2 << 30)
    DMA_BUF_MAX = 4*1024*1024
    DMA_RES     = DMA_BUF_MAX
    DMA_LENGTH  = DMA_RES + 4
    DMA_MAP_SIZE= DMA_BUF_MAX + 8
    DMA_BINDEX  = b'\x00\x00\x00\x00'
    DMA_RX_LEN  = b'\x00\x10\x00\x00'
    RECV_SIZE   = 4194304
else:
    FINISH_XFER = ord('a') + (ord('a') << 8) + (8 << 16) + (1 << 30)
    START_XFER  = ord('b') + (ord('a') << 8) + (8 << 16) + (1 << 30)
    XFER        = ord('c') + (ord('a') << 8) + (8 << 16) + (2 << 30)
    DMA_BUF_MAX = 64*1024*1024
    DMA_RES     = DMA_BUF_MAX
    DMA_LENGTH  = DMA_RES + 4
    DMA_MAP_SIZE= DMA_BUF_MAX + 8
    DMA_BINDEX  = b'\x00\x00\x00\x00'
    DMA_RX_LEN  = b'\x00\x10\x00\x00'
    RECV_SIZE   = 8388608

class DMA_Transmitter(object):
    def __init__(self, id=0):
        self.id = id
        if self.id >= 2:
            self.id = self.id + 1
                                                                           
    def open(self):
        if self.id == 0:                                           
            self.tx_dma_fd = os.open("/dev/dma_proxy_tx", os.O_RDWR)           
            self.rx_dma_fd = os.open("/dev/dma_proxy_rx", os.O_RDWR)
        else:
            self.tx_dma_fd = os.open("/dev/dma_proxy_tx%d" % self.id, os.O_RDWR)           
            self.rx_dma_fd = os.open("/dev/dma_proxy_rx%d" % self.id, os.O_RDWR)           
                                                                           
    def close(self):                                                       
        os.close(self.tx_dma_fd)                                           
        os.close(self.rx_dma_fd)                                           

    #===== time out =====
    # def callback_func(self):
    #     print("dma timeout")
    
    # def time_out(interval, callback=None):
    #     def decorator(func):
    #         def wrapper(*args, **kwargs):
    #             t =threading.Thread(target=func, args=args, kwargs=kwargs)
    #             t.setDaemon(True)
    #             t.start()
    #             t.join(interval) # wait time
    #             if t.is_alive() and callback:
    #                 return threading.Timer(0, callback, args=[args[0], ]).start()
    #             else:
    #                 return
    #         return wrapper
    #     return decorator

    # @time_out(3, callback_func)
    def send_flit_bin(self, flit_bin):
        '''                                                                
        发送flit                                                           
        '''                                                                
        length = len(flit_bin)                                             
        if length > DMA_BUF_MAX:                                           
            print("===<2>=== %s is larger than %dMB" % (flit_bin_file,DMA_BUF_MAX>>20))
            print("===<2>=== send flit length failed")                                 
            return 0                                                                   
        print("flit length: %d" % length)                                 
        with mmap.mmap(self.tx_dma_fd,DMA_MAP_SIZE,mmap.MAP_SHARED,mmap.PROT_WRITE | mmap.PROT_READ) as mm:
            mm[DMA_LENGTH:DMA_LENGTH+4]=struct.pack('I',length)
            mm[:length]=flit_bin                                                                           
            fcntl.ioctl(self.tx_dma_fd, XFER, DMA_BINDEX)                                                  
            tx_result = struct.unpack('I',mm[DMA_RES:DMA_RES+4])[0]
            # print("tx_result: %s" % tx_result)
            if tx_result != 0:                                                                             
                return 0
        return 1 

    # @time_out(4, callback_func)
    def recv_flit_bin(self):
        '''                                                                                                
        接收flit                                                                                           
        '''                                                                                    
        recv = bytearray()                                                                                       
        with mmap.mmap(self.rx_dma_fd,DMA_MAP_SIZE,mmap.MAP_SHARED,mmap.PROT_WRITE | mmap.PROT_READ) as mm:
            
            # mm[DMA_LENGTH:DMA_LENGTH+4]=DMA_RX_LEN
            # fcntl.ioctl(self.rx_dma_fd, XFER, DMA_BINDEX)                                                                                                               
            # rx_length = struct.unpack('I',mm[DMA_LENGTH:DMA_LENGTH+4])[0]
            # recv+=mm[:rx_length]
            
            last = False                                                                                   
            while not last:
                mm[DMA_LENGTH:DMA_LENGTH+4]=DMA_RX_LEN
                fcntl.ioctl(self.rx_dma_fd, XFER, DMA_BINDEX)                                                                                                               
                rx_length = struct.unpack('I',mm[DMA_LENGTH:DMA_LENGTH+4])[0]
                last_flit = struct.unpack('Q',mm[rx_length-8:rx_length])[0]
                last = last_flit == 0xffffffffffffffff
                if not last:                                                                           
                    print("rx_length is %d" % rx_length)
                recv+=mm[:rx_length]
                                                                           
        return recv

def recv(trans, client):
    s1.acquire()
    # for i in range(2):
    #     with open("flitout.bin","wb") as f:
    #         flits = trans.recv_flit_bin()
    #         client.sendall(flits)
    #         print("client send end")
    #         f.write(flits)

    flits = trans.recv_flit_bin()
    # if flits is None:
    #     print("none")
    #     flits = bytearray()
    client.sendall(flits)
    print("client send end")

    s1.release()

def start_tcp_server(ip, port, id):
    global active_ip
    # create socket
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_address = (ip, port)
 
    # bind port
    print("==Starting listen on ip %s, port %s" % server_address)
    sock.bind(server_address)
 
    # start listening, allow only one connection
    try:
        sock.listen(1)
    except socket.error:
        print("fail to listen on port %s" % e)
        sys.exit(1)
    receive_count = 0
    trans = DMA_Transmitter(id)
    #trans.open()

    while True:
        recv_len  = 0
        length    = 0

        while True:
            print("\nwaiting for connection")
            try:
                client, addr = sock.accept()
                stime = time.time_ns()
                trans.open()
            except:
                print("Kill by user!")
                sock.close() 
                sys.exit(1)
            #print("having a connection")
            print("addr is ", addr)
            break
            #if active_ip != "":
            #    print("active ip is %s" % active_ip)
            #if active_ip == "" or active_ip == addr[0]:
            #    active_ip = addr[0]
            #    print("set active ip to %s" % active_ip)
            #    break
            #else:
            #    print("there is still active ip %s" % active_ip)
            #    print("new ip connection will be ignored!")
            #    break
            #    client.close()

        left = bytearray()
        while True:
            try:
                msg = client.recv(RECV_SIZE)
            except socket.error:
                print("\nlength error\n")
                trans.close()
                length = 0
                break
            
            # if len(msg) == 4:
            #     receive_count += 1
            #     length = struct.unpack('I',msg)[0]
            #     print("recv at %d times with %d flits" % (receive_count,length))
            #     if length > 0:
            #         trans.socket_inst.sendall(msg)
            #         try:
            #             msg = trans.socket_inst.recv(1024)
            #         except socket.error:
            #             print("\nrecv error\n")
            #             length = 0
            #             break
            #         client.sendall(msg)
            # else:

            recv_len += len(msg)
            start = 0
            stop = len(msg)
            # print("msg len=%d" % stop)
            if length == 0:
                #f = open("flitin.bin","wb")
                if recv_len < 8:
                    client.close()
                    break
                length = struct.unpack('Q',msg[0:8])[0]
                recv_len -= 8
                start = 8
                print("length=%d" % length)
                if length > 0:
                    thread = threading.Thread(target=recv, args=(trans,client))
                    thread.start()
            else:
                pass
                #f.write(msg)
            #print("recv_len=%d" % recv_len)
            #begin_time = round(time.time() * 1000)
            if length > 0:
                if (stop + len(left)) % 8 != 0:
                    stop -= (stop + len(left)) % 8
                    print("stop=%d" % stop)
                    trans.send_flit_bin(left+msg[start:stop])
                    left = msg[stop:]
                else:
                    trans.send_flit_bin(left+msg[start:])
                    left = b''
                # print("send msg done")
            #end_time = round(time.time() * 1000)
            #delta_time = end_time - begin_time
            #if delta_time > 5:
                #print("delta_time =%d" % delta_time)

            if recv_len == length * 8 and length > 0:
                #f.close()
                etime = time.time_ns()                                              
                print("speed is %.3f Mbps" % (8*recv_len*1000000000/(etime-stime)/2**20))
                #print("waiting for respond")

            if msg == 0 or recv_len == length * 8:
                s1.acquire()
                s1.release()
                client.close()
                trans.close()
                break
                
        if (length == 0):
            #print("trans closed")
            active_ip = ""
            #break
 
    print("\n==Finish, close connect")
    sock.close() 

if __name__=='__main__':
    while(True):
        active_ip = ""
        id = 0
        if len(sys.argv)>1:
            id = int(sys.argv[1])
        try:
            start_tcp_server('0.0.0.0',id,0)
        except socket.error:
            print("\nreconnect\n")
        time.sleep(1)
