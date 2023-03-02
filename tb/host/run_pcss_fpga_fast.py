import os
import socket
import time
import struct
import sys

import numpy as np
import math
import pickle

class Node():
    def __init__(self):
        # packet par
        self.connect = 0
        self.pclass = 0b110 # write
        # node location
        self.node_x = 0
        self.node_y = 0
        self.dst_x = 0
        self.dst_y = 0
        self.dst_r2 = 0b000001
        self.dst_r1 = 0b000001
        # config reg
        self.enable = 0
        self.clear = 0
        self.spike_code = 0 # LIF
        self.reset = 0 # 0:ZERO, 1: -vth
        self.neu_num = 3 # [0,4095]
        self.vth = 3
        self.leak = 0
        self.x_in = 3
        self.y_in = 3
        self.x_start = 0
        self.y_start = 0
        self.x_out = 2
        self.y_out = 2
        self.z_out = 1
        self.x_k = 3
        self.y_k = 3
        self.pad = 1
        self.stride_log = 1
        self.rand_seed = 0
        # mem
        self.wgt_mem = []
        self.dst_mem = []
    
    def set_pclass(self,package_class):
        '''
        spike: 000
        data: 001 
        data_end: 010
        write: 110
        read: 111
        '''
        if package_class == 'data' :
            self.pclass = 0b001
        elif package_class == 'data_end' :
            self.pclass = 0b010
        elif package_class == 'write' :
            self.pclass = 0b110
        elif package_class == 'read' :
            self.pclass = 0b111
        else : # spike
            self.pclass = 0b000

    def set_node_loc(self,node_x,node_y,node_number):
        self.connect = node_y
        self.node_x = node_x
        self.node_y = node_y
        # input config data
        self.dst_x = (1 << 3) + (1 - node_x) # -(1-x)
        self.dst_y = 0b000
        self.dst_r2 = 1 << node_number//6 # [0,5]
        self.dst_r1 = 1 << node_number%6

    def set_neu_par(self,spike_code,reset,vth,leak):
        '''
        spike_code : 
            00: LIF
            01: Count
            10: Poisson
        reset : 
            0: ZERO
            1: -vth
        '''
        if spike_code == 'Count' : 
            self.spike_code = 1
        elif spike_code == 'Poisson' :
            self.spike_code = 2
        else : 
            self.spike_code = 0
        self.reset = reset
        self.vth = vth
        self.leak = leak

    def set_neu_num(self,neu_num):
        '''
        neu_num: [0,4095]
        '''
        self.neu_num = neu_num - 1 # TODO

    def set_conv(self,xin,yin,xstart,ystart,xout,yout,zout,xk,yk,pad,stride):
        self.x_in = xin
        self.y_in = yin
        self.x_start = xstart
        self.y_start = ystart
        self.x_out = xout
        self.y_out = yout
        self.z_out = zout
        self.x_k = xk
        self.y_k = yk
        self.pad = pad
        self.stride_log = int(math.log2(stride))

    def set_wgt_mem(self,weight_list):
        '''
        weight: [z, y, x]
        '''
        for z in weight_list:
            for y in z:
                for x in y:
                    self.wgt_mem.append(x)

    def set_dst_mem(self,dst_node_x,dst_node_y,dst_node_number):
        # after set_node_loc
        if dst_node_x >= self.node_x :
            dst_mem_x = dst_node_x - self.node_x
        else : 
            dst_mem_x = (1 << 3) + self.node_x - dst_node_x

        if dst_node_y >= self.node_y :
            dst_mem_y = dst_node_y - self.node_y
        else : 
            dst_mem_y = (1 << 3) + self.node_y - dst_node_y


        if dst_node_number//6 > 0:
            for i in range(0, dst_node_number//6):
                dst_mem_r2 = 1 << i
                dst_mem_r1 = 63 #06'b111111
                flg = 1 # continue
                tmp = (dst_mem_y << 17) + (dst_mem_x << 13) + (dst_mem_r2 << 7) + (dst_mem_r1 << 1) + flg
                self.dst_mem.append(tmp)

        dst_mem_r2 = 1 << (dst_node_number//6)
        dst_mem_r1 = 0
        for i in range(0,dst_node_number%6):
            dst_mem_r1 += 1 << i
        flg = 0 # not continue
        tmp = (dst_mem_y << 17) + (dst_mem_x << 13) + (dst_mem_r2 << 7) + (dst_mem_r1 << 1) + flg
        self.dst_mem.append(tmp)

class Configuration(object):
    def __init__(self, node_list=[]):
        self.node_list = node_list

    def gen_conf(self,config=[]):
        
        for node in self.node_list:
            flit_head = (node.connect << 59) + (node.pclass << 56) \
                + (node.dst_y << 52) + (node.dst_x << 48) + (node.dst_r2 << 42) + (node.dst_r1 << 36)
            # write reg bank
            '''
            nm_neu_num:
                [11:0] the number of neurons
            addr : 0x1
            '''
            waddr = 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.neu_num)
            config.append(ss)
            '''
            nm_status:
                [0] enable bit
                [1] clear bit
                [2:3] spike code : 00 LIF, 01 Count, 10 Poisson
                [4] reset bit : 0 zero, 1 -vth
            addr : 0x0
            '''
            # clear
            node.enable = 0
            node.clear = 1
            waddr = 0
            tmp = (node.reset << 4) + (node.spike_code << 2) + (node.clear << 1) + node.enable
            ss = "%016x" % (flit_head + (waddr << 21) + tmp)
            config.append(ss)
            '''
            nm_vth: [19:0]
            nm_leak: [19:0]
            '''
            waddr = 2
            ss = "%016x" % (flit_head + (waddr << 21) + (int(node.vth) & 0xfffff))
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + (int(node.leak) & 0xfffff))
            config.append(ss)
            '''
            x_in : [7:0] 0x4
            y_in : [7:0] 0x5
            z_out : [7:0] 0x6
            x_k : [2:0] 0x7
            y_k : [2:0] 0x8
            x_out : [7:0] 0x9
            y_out : [7:0] 0xa
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.x_in)
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.y_in)
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.z_out)
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.x_k)
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.y_k)
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.x_out)
            config.append(ss)

            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.y_out)
            config.append(ss)

            '''
            pad : valid
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.pad)
            config.append(ss)
            '''
            stride_log : 0,1,2,3,4
            stride : 1,2,4,8,16
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.stride_log)
            config.append(ss)
            '''
            xk_yk
            addr : 0xd
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.x_k*node.y_k)
            config.append(ss)
            '''
            rand_seed
            addr : 0xe
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.rand_seed)
            config.append(ss)
            '''
            x_start
            addr : 0xf
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.x_start)
            config.append(ss)
            '''
            y_start
            addr : 0xf
            '''
            waddr += 1
            ss = "%016x" % (flit_head + (waddr << 21) + node.y_start)
            config.append(ss)

            # write wgt mem
            '''
            0x1000 ~ 0x1FFF
            width : 16bit
            '''
            waddr = 0x1000
            for wgt in node.wgt_mem:
                ss = "%016x" % (flit_head + (waddr << 21) + (int(wgt) & 0xffff))
                config.append(ss)
                waddr += 1

            # write dst mem
            '''
            0x2000 ~ 0x2FFF
            '''
            waddr = 0x2000
            for dst in node.dst_mem:
                ss = "%016x" % (flit_head + (waddr << 21) + int(dst))
                config.append(ss)
                waddr += 1

            # enable
            node.enable = 1
            node.clear = 0
            waddr = 0
            tmp = (node.reset << 4) + (node.spike_code << 2) + (node.clear << 1) + node.enable
            ss = "%016x" % (flit_head + (waddr << 21) + tmp)
            config.append(ss)

        # print('config done')
        return config   

    def gen_clear(self,spike=[]):

        for node in self.node_list:
            flit_head = (node.connect << 59) + (node.pclass << 56) \
                + (node.dst_y << 52) + (node.dst_x << 48) + (node.dst_r2 << 42) + (node.dst_r1 << 36)
            '''
            nm_status:
                [0] enable bit
                [1] clear bit
                [2:3] spike code : 00 LIF, 01 Count, 10 Poisson
                [4] reset bit : 0 zero, 1 -vth
            addr : 0x0
            '''
            # clear
            node.enable = 0
            node.clear = 1
            waddr = 0
            tmp = (node.reset << 4) + (node.spike_code << 2) + (node.clear << 1) + node.enable
            ss = "%016x" % (flit_head + (waddr << 21) + tmp)
            spike.append(ss)
            # enable
            node.enable = 1
            node.clear = 0
            waddr = 0
            tmp = (node.reset << 4) + (node.spike_code << 2) + (node.clear << 1) + node.enable
            ss = "%016x" % (flit_head + (waddr << 21) + tmp)
            spike.append(ss)

        # print('clear done')
        return spike


class Input_Node():
    def __init__(self):
        # packet par
        self.connect = 0
        self.pclass = 0b001 # Data
        # node location
        self.node_x = 0
        self.node_y = 0
        self.dst_x = 0
        self.dst_y = 0
        self.dst_r2 = 0b000001
        self.dst_r1 = 0b000001
        # config reg
        self.spike_code = 0 # LIF
        self.reset = 0 # 0:ZERO, 1: -vth

    def set_node_loc(self,node_x,node_y,node_number):
        self.connect = node_y
        self.node_x = node_x
        self.node_y = node_y
        # input config data
        self.dst_x = (1 << 3) + (1 - node_x) # -(1-x)
        self.dst_y = 0b000
        self.dst_r2 = 1 << node_number//6 # [0,5]
        self.dst_r1 = 1 << node_number%6

    def set_neu_par(self,spike_code,reset):
        '''
        spike_code : 
            00: LIF
            01: Count
            10: Poisson
        reset : 
            0: ZERO
            1: -vth
        '''
        if spike_code == 'Count' : 
            self.spike_code = 1
        elif spike_code == 'Poisson' :
            self.spike_code = 2
        else : 
            self.spike_code = 0
        self.reset = reset


    def gen_input(self, spike=[], feature_map=[]):

        # unenable
        self.pclass = 0b110 # write
        flit_head = (self.connect << 59) + (self.pclass << 56) \
                    + (self.dst_y << 52) + (self.dst_x << 48) + (self.dst_r2 << 42) + (self.dst_r1 << 36)
        enable = 0
        clear = 0
        waddr = 0
        tmp = (self.reset << 4) + (self.spike_code << 2) + (clear << 1) + enable
        ss = "%016x" % (flit_head + (waddr << 21) + tmp)
        spike.append(ss)

        # send data
        self.pclass = 0b001 # data
        flit_head = (self.connect << 59) + (self.pclass << 56) \
                    + (self.dst_y << 52) + (self.dst_x << 48) + (self.dst_r2 << 42) + (self.dst_r1 << 36)
        for i,y in enumerate(feature_map) :
            for j,x in enumerate(y):
                if i == len(feature_map)-1 and j == len(y)-1:
                    self.pclass = 0b010 # data_end
                    flit_head = (self.connect << 59) + (self.pclass << 56) \
                        + (self.dst_y << 52) + (self.dst_x << 48) + (self.dst_r2 << 42) + (self.dst_r1 << 36)

                flit_data = (int(x) & 0xffff) # 16bit
                ss = "%016x" % (flit_head + flit_data)
                spike.append(ss)
    
        
        # enable
        self.pclass = 0b110 # write
        flit_head = (self.connect << 59) + (self.pclass << 56) \
                    + (self.dst_y << 52) + (self.dst_x << 48) + (self.dst_r2 << 42) + (self.dst_r1 << 36)
        enable = 1
        clear = 0
        waddr = 0
        tmp = (self.reset << 4) + (self.spike_code << 2) + (clear << 1) + enable
        ss = "%016x" % (flit_head + (waddr << 21) + tmp)
        spike.append(ss)

        # print('spike done')
        return spike

class Tik():
    def __init__(self, tik_num=0, tik_len=4096):
        # tik par
        self.tik_num = tik_num
        self.tik_len = tik_len
        self.pclass = 0b011 # tik

    def gen_input(self,spike=[]):

        # gen tik
        self.pclass = 0b011 # tik
        for i in range(self.tik_num):
            ss = "%016x" % ((self.pclass << 56) + self.tik_len)
            spike.append(ss)

        # gen tik end
        ss = "%016x" % ((self.pclass << 56) + (1 << 32) + self.tik_len)
        spike.append(ss)

        # print('tik done')
        return spike

class PCSS():
    def __init__(self):
        # spk node par
        self.reset = 1
        self.vth = 0 # TODO
        self.leak = 255 # TODO
        # tik par
        self.tik_num = 8
        self.tik_len = 1048576 # 32 bit
        # node
        self.node_list = []
        self.conf = None
        self.tik_init = Tik(tik_num=0,tik_len=self.tik_len)
        self.tik_send = Tik(tik_num=self.tik_num,tik_len=self.tik_len)
        # config & spike file
        self.config = []
        self.spike = []

    def init_pcss(self):

        # read weight
        with open('track_weight.pkl', 'rb') as f:
            track_wgt = pickle.load(f)

        # read vth
        with open('track_vth.pkl', 'rb') as f:
            track_vth = pickle.load(f)

        # spike coding node
        for x in range(4):
            for y in range(4):
                if x == 3:
                    if y == 3:
                        neu_num = 63*63
                        xout = 63
                        yout = 63
                    else :
                        neu_num = 63*64
                        xout = 63
                        yout = 64
                else :
                    if y == 3:
                        neu_num = 64*63
                        xout = 64
                        yout = 63
                    else :
                        neu_num = 64*64
                        xout = 64
                        yout = 64
                
                node_number = y*4 + x
                node_tmp = Node()
                node_tmp.set_pclass(package_class='write')
                node_tmp.set_node_loc(node_x=1,node_y=0,node_number=node_number)
                node_tmp.set_neu_par(spike_code='Count',reset=self.reset,vth=self.vth,leak=self.leak)
                node_tmp.set_neu_num(neu_num=neu_num)
                node_tmp.set_conv(xin=0,yin=0,xstart=64*x,ystart=64*y,xout=xout,yout=yout,zout=0,xk=0,yk=0,pad=0,stride=4) #TODO
                node_tmp.set_dst_mem(dst_node_x=0,dst_node_y=0,dst_node_number=8)
                self.node_list.append(node_tmp)

        # node par
        vth = track_vth[0]
        leak = 0

        # conv1 node
        node_num = 8
        neu_num = 64*64
        for n in range(0, node_num):
            node_tmp = Node()
            node_tmp.set_pclass(package_class='write')
            node_tmp.set_node_loc(node_x=0,node_y=0,node_number=n)
            node_tmp.set_neu_par(spike_code='LIF',reset=self.reset,vth=vth[n],leak=leak)
            node_tmp.set_neu_num(neu_num=neu_num)
            node_tmp.set_conv(xin=255,yin=255,xstart=0,ystart=0,xout=64,yout=64,zout=n,xk=3,yk=3,pad=0,stride=4) #TODO
            node_tmp.set_wgt_mem(weight_list=track_wgt[0][n])
            node_tmp.set_dst_mem(dst_node_x=0,dst_node_y=1,dst_node_number=16)
            self.node_list.append(node_tmp)

        # node par
        vth = track_vth[1]
        leak = 0

        # conv2 node
        node_num = 16
        neu_num = 31*31
        for n in range(0, node_num):
            node_tmp = Node()
            node_tmp.set_pclass(package_class='write')
            node_tmp.set_node_loc(node_x=0,node_y=1,node_number=n)
            node_tmp.set_neu_par(spike_code='LIF',reset=self.reset,vth=vth[n],leak=leak)
            node_tmp.set_neu_num(neu_num=neu_num)
            node_tmp.set_conv(xin=64,yin=64,xstart=0,ystart=0,xout=31,yout=31,zout=n,xk=3,yk=3,pad=0,stride=2)
            node_tmp.set_wgt_mem(weight_list=track_wgt[1][n])
            node_tmp.set_dst_mem(dst_node_x=1,dst_node_y=1,dst_node_number=8)
            self.node_list.append(node_tmp)

        # node par
        vth = track_vth[2]
        leak = 0

        # conv3 node
        node_num = 8
        neu_num = 29*29
        for n in range(0, node_num):
            node_tmp = Node()
            node_tmp.set_pclass(package_class='write')
            node_tmp.set_node_loc(node_x=1,node_y=1,node_number=n)
            node_tmp.set_neu_par(spike_code='LIF',reset=self.reset,vth=vth[n],leak=leak)
            node_tmp.set_neu_num(neu_num=neu_num)
            node_tmp.set_conv(xin=31,yin=31,xstart=0,ystart=0,xout=29,yout=29,zout=n,xk=3,yk=3,pad=0,stride=1)
            node_tmp.set_wgt_mem(weight_list=track_wgt[2][n])
            node_tmp.set_dst_mem(dst_node_x=2,dst_node_y=1,dst_node_number=1)
            self.node_list.append(node_tmp)

        # gen config
        self.conf = Configuration(node_list=self.node_list)
        self.config = self.conf.gen_conf(config=[])
        self.config = self.tik_init.gen_input(spike=self.config)

    #---------------------
    #       gen spk
    #---------------------
    def gen_spk(self,track_fm=[]):

        # clear
        self.spike = self.conf.gen_clear(spike=[]) # fm init

        # load fm
        if track_fm is not None:
            with open('track_fm_255.pkl', 'rb') as f:
                track_fm = pickle.load(f)

        for x in range(4):
            for y in range(4):
                if x == 3:
                    dx = 63
                else :
                    dx = 64
                if y == 3:
                    dy = 63
                else :
                    dy = 64
                node_number = y*4 + x
                node_tmp = Input_Node()
                node_tmp.set_node_loc(node_x=1,node_y=0,node_number=node_number)
                node_tmp.set_neu_par(spike_code='Count',reset=self.reset)
                fm = [track_fm[i][64*x : 64*x+dx] for i in range(64*y, 64*y+dy)]
                self.spike = node_tmp.gen_input(spike=self.spike,feature_map=fm)

        self.spike = self.tik_send.gen_input(spike=self.spike)

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

    def send_flit(self, flit_list=[], directions=0):
        '''
        发送flit
        '''
        # with open(flit_file, 'r') as file:
        #         flit_list = file.readlines()
        length = len(flit_list)
        if length > 2**26:
            print("===<2>=== flit_file is larger than 0.25GB")
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

def run_pcss(tc="", flit_file=[], recv = True, ip = "10.11.8.238", port=1): # 10.11.8.238
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
    res=trans.send_flit(flit_list=flit_file) # send
    if res == 0:
        return
    end_time = time.time_ns()
    print("===<2>=== send flit data   succeed")
    print('===<2>=== tcp sent elapsed : %.3f ms' % ((end_time - start_time)/1000000))

    # f = open("flitout.txt", "wb") 
    flitout = []
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
                flitout.append(hl)
                # f.write (hl + b"\n")
                # print(hl)
                hl = b""
                index = 0
                tot = tot + 1
    end_time = time.time_ns()
    # f.close()
    # fbin.close()
    trans.socket_inst.close()
    print('===<2>=== tcp recv elapsed : %.3f ms with %d flits' % ((end_time - start_time)/1000000,tot))

    return flitout

if __name__ == "__main__":
    # socket
    id = 1
    if len(sys.argv)>1:
        id = int(sys.argv[1])
    # init
    net = PCSS()
    net.init_pcss()
    run_pcss(flit_file=net.config, port=id)
    # send fm
    # for loop in range(10):
    stime = time.time_ns()
    net.gen_spk(track_fm=[])
    spk_recv = run_pcss(flit_file=net.spike, port=id)
    etime = time.time_ns()
    print("\n<--total time elapsed : %.3f ms-->\n" % ((etime - stime)/1000000.0))

    f = open("flitout.txt", "wb")
    for line in spk_recv:
        f.write(line+b'\n')
    f.close()
    print('write done')

