import numpy as np
import math
import pickle

class Node():
    def __init__(self, tik=0):
        # packet par
        self.tik = tik
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
        self.dst_x = (1 << 3) + (2 - node_x) # -(2-x)
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

        dst_mem_r2 = 0
        dst_mem_r1 = 0
        for node_num in range(0,dst_node_number):
            dst_mem_r2 += 1 << node_num//6 # [0,5]
            dst_mem_r1 += 1 << node_num%6

        flg = 0 # not continue
        tmp = (dst_mem_y << 16) + (dst_mem_x << 12) + (dst_mem_r2 << 6) + dst_mem_r1
        self.dst_mem.append(tmp)

class Configuration(object):
    def __init__(self, node_list=[]):
        self.node_list = node_list

    def gen_conf(self,filename="config.txt"):
        ## gen config file
        f=open(filename,'w')
        
        for node in self.node_list:
            flit_head = (node.tik << 64) + (node.connect << 59) + (node.pclass << 56) \
                + (node.dst_y << 52) + (node.dst_x << 48) + (node.dst_r2 << 42) + (node.dst_r1 << 36)
            # write reg bank
            '''
            nm_neu_num:
                [11:0] the number of neurons
            addr : 0x1
            '''
            waddr = 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.neu_num)
            f.write(ss+'\n')
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
            ss = "%018x" % (flit_head + (waddr << 21) + tmp)
            f.write(ss+'\n')
            '''
            nm_vth: [19:0]
            nm_leak: [19:0]
            '''
            waddr = 2
            ss = "%018x" % (flit_head + (waddr << 21) + node.vth)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.leak)
            f.write(ss+'\n')
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
            ss = "%018x" % (flit_head + (waddr << 21) + node.x_in)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.y_in)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.z_out)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.x_k)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.y_k)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.x_out)
            f.write(ss+'\n')

            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.y_out)
            f.write(ss+'\n')

            '''
            pad : valid
            '''
            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.pad)
            f.write(ss+'\n')
            '''
            stride_log : 0,1,2,3,4
            stride : 1,2,4,8,16
            '''
            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.stride_log)
            f.write(ss+'\n')
            '''
            xk_yk
            addr : 0xd
            '''
            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.x_k*node.y_k)
            f.write(ss+'\n')
            '''
            rand_seed
            addr : 0xe
            '''
            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.rand_seed)
            f.write(ss+'\n')
            '''
            x_start
            addr : 0xf
            '''
            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.x_start)
            f.write(ss+'\n')
            '''
            y_start
            addr : 0xf
            '''
            waddr += 1
            ss = "%018x" % (flit_head + (waddr << 21) + node.y_start)
            f.write(ss+'\n')

            # write wgt mem
            '''
            0x1000 ~ 0x1FFF
            '''
            waddr = 0x1000
            for wgt in node.wgt_mem:
                        ss = "%018x" % (flit_head + (waddr << 21) + int(wgt))
                        f.write(ss+'\n')
                        waddr += 1

            # write dst mem
            '''
            0x2000 ~ 0x2FFF
            '''
            waddr = 0x2000
            for dst in node.dst_mem:
                ss = "%018x" % (flit_head + (waddr << 21) + int(dst))
                f.write(ss+'\n')
                waddr += 1

            # enable
            node.enable = 1
            node.clear = 0
            waddr = 0
            tmp = (node.reset << 4) + (node.spike_code << 2) + (node.clear << 1) + node.enable
            ss = "%018x" % (flit_head + (waddr << 21) + tmp)
            f.write(ss+'\n')

        f.close()
        print('config done')

        
#---------------------
#       node
#---------------------
