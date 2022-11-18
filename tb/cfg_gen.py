import numpy as np

tik = 0
connect = 0
pclass = 0b110 # write
dst_x = 0b1000 # -1
dst_y = 0
r_2 = 0b000001
r_1 = 0b000001
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
node_x = 1
node_y = 1
node_r2 = 0b000001
node_r1 = 0b000001
enable = 0
clear = 0
spike_code = 0 # LIF
reset = 0 # zero
neu_num = 4
vth = 3
leak = 0
x_in = 3
y_in = 3
x_out = 2
y_out = 2
z_out = 1
x_k = 3
y_k = 3
pad = 1
stride_log = 1

# wgt mem
n = np.arange(0,9)
n = n.reshape(3,3)
wgt_mem = np.expand_dims(n,2).repeat(3,axis=2)

# dst mem
dst_mem_x = 1
dst_mem_y = 1
dst_mem_r2 = 0
dst_mem_r1 = 0
flg = 1
dst_mem = np.zeros(2)
dst_mem[0] = (dst_mem_y << 16) + (dst_mem_x << 12) + (dst_mem_r2 << 6) + dst_mem_r1

## gen config file
filename = "config.txt"
f=open(filename,'w')
flit_head = (tik << 64) + (connect << 59) + (pclass << 56) \
          + (dst_y << 52) + (dst_x << 48) + (r_2 << 42) + (r_1 << 36)

# write reg bank
'''
nm_status:
    [0] enable bit
    [1] clear bit
    [2:3] spike code : 00 LIF, 10 Poisson
    [4] reset bit : 0 zero, 1 -vth
'''
# clear
enable = 0
clear = 1
waddr = 0
tmp = (reset << 4) + (spike_code << 2) + (clear << 1) + enable
ss = "%018x" % (flit_head + (waddr << 21) + tmp)
f.write(ss+'\n')

'''
nm_neu_num:
    [11:0] the number of neurons
'''
waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + neu_num)
f.write(ss+'\n')
'''
nm_vth: [19:0]
nm_leak: [19:0]
'''
waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + vth)
f.write(ss+'\n')

waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + leak)
f.write(ss+'\n')
'''
x_in : [7:0]
y_in : [7:0]
x_out : [7:0]
y_out : [7:0]
z_out : [7:0]
x_k : [2:0]
y_k : [2:0]
'''
waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + x_in)
f.write(ss+'\n')

waddr += 1
tmp = vth
ss = "%018x" % (flit_head + (waddr << 21) + y_in)
f.write(ss+'\n')

waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + x_out)
f.write(ss+'\n')

waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + y_out)
f.write(ss+'\n')

waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + z_out)
f.write(ss+'\n')

waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + x_k)
f.write(ss+'\n')

waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + y_k)
f.write(ss+'\n')
'''
pad : valid
'''
waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + pad)
f.write(ss+'\n')
'''
stride_log : 0,1,2,3,4
stride : 1,2,4,8,16
'''
waddr += 1
ss = "%018x" % (flit_head + (waddr << 21) + stride_log)
f.write(ss+'\n')

# write wgt mem
'''
0x1000 ~ 0x1FFF
'''
waddr = 0x1000
for x in wgt_mem:
    for y in x:
        for wgt in y:
            ss = "%018x" % (flit_head + (waddr << 21) + int(wgt))
            f.write(ss+'\n')
            waddr += 1

# write dst mem
'''
0x2000 ~ 0x2FFF
'''
waddr = 0x1000
for dst in dst_mem:
    ss = "%018x" % (flit_head + (waddr << 21) + int(dst))
    f.write(ss+'\n')
    waddr += 1

# enable
enable = 1
clear = 0
waddr = 0
tmp = (reset << 4) + (spike_code << 2) + (clear << 1) + enable
ss = "%018x" % (flit_head + (waddr << 21) + tmp)
f.write(ss+'\n')

f.close()
print('config done')


## gen spk file
filename = "spike.txt"
f=open(filename,'w')

max_time = 5
for tik in range(1, max_time + 1):
    flit_head = (tik << 64) + (connect << 59) + (pclass << 56) \
          + (dst_y << 52) + (dst_x << 48) + (r_2 << 42) + (r_1 << 36)
    flit_data = (s_z << 16) + (s_y << 8) + s_x
    ss = "%018x" % (flit_head + flit_data)
    f.write(ss+'\n')

f.close()
print('spike done')
