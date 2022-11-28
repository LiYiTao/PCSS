import numpy as np

class Node():

    def __init__(self, tik=0, connect=0, dst_x=0, dst_y=0, dst_r2=0b000001, dst_r1=0b000001) -> None:
        # packet par
        self.tik = tik
        self.connect = connect
        self.pclass = 0b110 # spike: 000, data: 001, data_end: 010, write: 110, read: 111
        # node location
        self.node_x = dst_x
        self.node_y = dst_y
        self.node_r2 = dst_r2
        self.node_r1 = dst_r1
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
        self.x_out = 2
        self.y_out = 2
        self.z_out = 1
        self.x_k = 3
        self.y_k = 3
        self.pad = 1
        self.stride_log = 1
        self.rand_seed = 0
    
    def WgtMem(self):
        n = np.arange(1,10)
        n = n.reshape(3,3)
        self.wgt_mem = np.expand_dims(n,2).repeat(3,axis=2)

    def DstMem(self):
        dst_mem_x = 1
        dst_mem_y = 1
        dst_mem_r2 = 0
        dst_mem_r1 = 0
        flg = 1 # continue
        self.dst_mem = np.zeros(2)
        self.dst_mem[0] = (dst_mem_y << 16) + (dst_mem_x << 12) + (dst_mem_r2 << 6) + dst_mem_r1

    def GenConf(self):
        ## gen config file
        filename = "config.txt"
        f=open(filename,'w')
        flit_head = (self.tik << 64) + (self.connect << 59) + (self.pclass << 56) \
                + (self.node_y << 52) + (self.node_x << 48) + (self.node_r2 << 42) + (self.node_r1 << 36)

        # write reg bank
        '''
        nm_neu_num:
            [11:0] the number of neurons
        addr : 0x1
        '''
        waddr = 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.neu_num)
        f.write(ss+'\n')
        '''
        nm_status:
            [0] enable bit
            [1] clear bit
            [2:3] spike code : 00 LIF, 10 Poisson
            [4] reset bit : 0 zero, 1 -vth
        addr : 0x0
        '''
        # clear
        self.enable = 0
        self.clear = 1
        waddr = 0
        tmp = (self.reset << 4) + (self.spike_code << 2) + (self.clear << 1) + self.enable
        ss = "%018x" % (flit_head + (waddr << 21) + tmp)
        f.write(ss+'\n')
        '''
        nm_vth: [19:0]
        nm_leak: [19:0]
        '''
        waddr = 2
        ss = "%018x" % (flit_head + (waddr << 21) + self.vth)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.leak)
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
        ss = "%018x" % (flit_head + (waddr << 21) + self.x_in)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.y_in)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.z_out)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.x_k)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.y_k)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.x_out)
        f.write(ss+'\n')

        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.y_out)
        f.write(ss+'\n')

        '''
        pad : valid
        '''
        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.pad)
        f.write(ss+'\n')
        '''
        stride_log : 0,1,2,3,4
        stride : 1,2,4,8,16
        '''
        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.stride_log)
        f.write(ss+'\n')
        '''
        xk_yk
        addr : 0xd
        '''
        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.x_k*self.y_k)
        f.write(ss+'\n')
        '''
        rand_seed
        addr : 0xe
        '''
        waddr += 1
        ss = "%018x" % (flit_head + (waddr << 21) + self.rand_seed)
        f.write(ss+'\n')

        # write wgt mem
        '''
        0x1000 ~ 0x1FFF
        '''
        waddr = 0x1000
        for x in self.wgt_mem:
            for y in x:
                for wgt in y:
                    ss = "%018x" % (flit_head + (waddr << 21) + int(wgt))
                    f.write(ss+'\n')
                    waddr += 1

        # write dst mem
        '''
        0x2000 ~ 0x2FFF
        '''
        waddr = 0x2000
        for dst in self.dst_mem:
            ss = "%018x" % (flit_head + (waddr << 21) + int(dst))
            f.write(ss+'\n')
            waddr += 1

        # enable
        self.enable = 1
        self.clear = 0
        waddr = 0
        tmp = (self.reset << 4) + (self.spike_code << 2) + (self.clear << 1) + self.enable
        ss = "%018x" % (flit_head + (waddr << 21) + tmp)
        f.write(ss+'\n')

        f.close()
        print('config done')

tik = 0
connect = 1
dst_x = 0b1000 # -1
dst_y = 0
dst_r2 = 0b000001
dst_r1 = 0b000001
# spike
s_x = 0
s_y = 0
s_z = 0
# data
fm = 0
cnt = 0
# read & write
addr = 0
data = 0
#---------------------
#       node
#---------------------
n = Node(tik=tik,connect=connect,dst_y=dst_y,dst_x=dst_x,dst_r2=dst_r2,dst_r1=dst_r1)
n.WgtMem()
n.DstMem()
n.GenConf()

#---------------------
#       gen spk
#---------------------
filename = "spike.txt"
f=open(filename,'w')

pclass = 0b000 # spike
timesteps = 8
for tik in range(1, timesteps + 1):
    flit_head = (tik << 64) + (connect << 59) + (pclass << 56) \
          + (dst_y << 52) + (dst_x << 48) + (dst_r2 << 42) + (dst_r1 << 36)
    flit_data = (s_z << 16) + (s_y << 8) + s_x
    ss = "%018x" % (flit_head + flit_data)
    f.write(ss+'\n')
    # spk gen
    if s_x < 3: s_x += 1
    else: s_x = 0

f.close()
print('spike done')
