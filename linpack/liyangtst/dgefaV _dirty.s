#REAL a[],int lda,int n, int ipvt[]
# pointer, 100, 100, pointer
.section .text                       
.global dgefaV_dirty
dgefaV_dirty:
        li              t0, 1
        sub             s10, a2, t0                 # s10 = nm1 = n-1
loopdgefa_init:
        li              s11, 0                            
loopdgefa_start:
        mv              s8, s11                     # s8 = k 
        addi            s11, s11, 1                 # s11 = kp1 = k+1
idamax_init:
        mv              s9, a0                      # s9 the pointer to a[0]
        mv              s7, a3                      # s7 the pointer to ipvt
        mv              s6, a2                      # s6 the dimension n
        add             s4, s8, s8                  # s4 = k+k
        slli            s4, s4, 3                       # <<3 for double takes 8 bytes
        mul             s4, s4, t0                  # s4 = &a[k,k] - &a[0,0]
        add             a1, s9, t0                  # a1 = &a[k,k]
        sub             a0, a2, s8                  # a0 = dimension = n - k
idamax:
#########################################################
#int n, double *dx, int incx, int ntimes, int *result_ret
#########################################################
        vsetvli         t0, zero, e64, m1, ta, ma
loop_init:
        vl1re64.v       v4, (a1)
        vsetvli         t0, zero, e64, m1, ta, ma
        vfabs.v         v4, v4
        slli            t1, t0, 3          
        vsetvli         t0, zero, e32, m1, ta, ma 
        vmv.v.i         v20, 1              # 初始化索引向量，用于存储最大值位置
        vmv.v.i         v24, 1              
        vmv.v.i         v28, 1 
        li              a7, 1        
max_loop_idamax:
        add             a1, a1, t1
        vsetvli         t0, zero, e64, m1, ta, ma
        vl1re64.v       v16, (a1)
        vmflt.vv        v0, v16, v4
        vmerge.vvm      v4, v16, v4, v0
        vsetvli         t0, zero, e32, m1, ta, ma
        vadd.vv         v24, v28, v24
        vmerge.vvm      v20, v24, v20, v0
        addi            a7, a7, 1
        bne             a7, a0, max_loop_idamax
loop_breaker:
        vsetvli         t0, zero, e32, m1, ta, ma
        vs1r.v          v20, (a4)
#向a4 存储了parr*n个最大元素位置（从对角线开始数）（min为1）   
#########################################################    
#########################################################
after_idamax:       # l = idamax(n-k,&a[lda*k+k],1) + k;    ipvt[k] = l;
#ipvt原本存储了一个矩阵的各行idamax位置
#现在ipvt1-64应当存储1-64号矩阵各行idamax位置,第一行存每一个ipvt的1号元素，以此类推
        vsetvli         t0, zero, e32, m1, ta, ma
        mv              t1, s8      
        slli            t1, t1, 3           
        mul             t1, t1, t0          # t1 the offset = k * parr (byte) = &ipvt[0][k] - &ipvt[0][0]
        add             t1, t1, s7          # t1 = &ipvt [0][k]
        vadd.vx        v20, v20, s8        # l = idamax(n-k,&a[lda*k+k],1) + k
        vs1r.v          v20, (t1)           # 向&ipvt[0] + k*parr 存储了64个矩阵第k行最大元素位置,也就是l
if_swap_dgefa:          #not an actually working if     #swap a[lda*k+l] and a[lda*k+k];
        vsetvli         t0, zero, e64, m1, ta, ma
        lw              t2, 0(t1)           # t1 the pointer to ipvt(0)[k] = l
                                            ###trick         
        add             s4, s8, s9          # s4 = l+k
        slli            s4, s4, 2           # t2 = &a[0] + (l+k) >>2 for int is 4 byte
        slli            t3, s8, 1           # t3 = 2k
        slli            t3, t3, 3           # t3 = 2k << 3 for double takes 8 byte
        add             t3, t3, s9          # t3 = &a[0] + (k+k)
        vl1re64.v       v4, (t2)            # v4 = a[k,l]
        vl1re64.v       v8, (t3)            # v8 = a[k,k]
        vs1r.v          v4, (t3)
        vs1r.v          v8, (t2)            # swap
dscal_init:
        li              t2, -1
        fcvt.d.w        fa2, t2
        vfrdiv.vf       v12, v4, fa2   
                        ######## mv    a1, v12  # t = -one / a[k,k]
                        ######## v12在dscalv原本命名为v8
        slli            t4, t0, 3
        add             t3, t3, t4
        mv              a2, t3              ###check
        sub             t1, s6, s11         # t1 = n - kp1
        mul             a0, t1, t0          # data_size = (n-k-1) * parr (double)
#########################################################   
#dscalvtst(int, double*, double*, int): #a0 = data_size (how many doubles)
#########################################################
dscalvtst:                         
        vsetvli         t0, zero, e64, m1, ta, ma
        slli            a7, a0, 3
        add             a4, a2, a7
        slli            a5, t0, 3     
                        #vl1re64.v       v8, (a1) 替换为前面残留的v12
.LBB0_6:                                                     
        vl1re64.v       v4, (a2)               
        vfmul.vv        v4, v12, v4         #   v8 替换为 v12                                         
        vs1r.v          v4, (a2)
        add             a2, a2, a5
        blt             a2, a4, .LBB0_6  
#########################################################    
#########################################################
innerloop_init:
        mv              s5, s11         #s5 the j; set init j = kp1
inner_ifswapdgefa:
#########################################################    
#########################################################
        vsetvli         t0, zero, e64, m1, ta, ma
        lw              t2, (t1)            # t1 the pointer to ipvt(0)[k] = l
                                            # t2 = l
                                            ###trick
        add             s4, s9, s5          # s4 = j + l
        slli            s4, s4, 2           # s4 << 2 for int takes 4 byte each
        add             t2, t2, s4          # t2 = &a[0] + (j+l)
        add             t3, s8, s5          # t3 = j + k
        add             t3, t3, s9          # t3 = &a[0] + (j+k)
        vl1re64.v       v4, (t2)            # v4 = a[j,l]
        vmv.v.v         v1, v4              # t(vector) put into v1 for daxpy
        vl1re64.v       v8, (t3)            # v8 = a[j,k]
        vs1r.v          v4, (t3)
        vs1r.v          v8, (t2)            #swap
#########################################################    
#########################################################
daxpy_init:
        sub              a0, s5, s11
#########################################################
#daxpy_modify(int, double, double*, int, double*, int)    
#########################################################
daxpy:
        blez				a0, innerloop_breaker
        
        mul                         a0, a0, t0
        mv		            t1, a0
        vsetvli			    t0, a0, e64, m1 
loop_daxpy:				
        #vfmv.v.f		    v0,	fa0             #   check
        vl1re64.v		    v1, (a1)
        vl1re64.v		    v2, (a3)
        vfmacc.vv		    v2, v0, v1
        vs1r.v			    v2, (a3)
        slli				t2, t0, 3	
        add					a1, a1, t2
        add					a3, a3, t2
        sub					t1, t1, t0
        bnez				t1, loop_daxpy
#########################################################    
#########################################################
innerloop_breaker:
        add             s5, s5, 1
        bne             s5, s6, inner_ifswapdgefa
loopdgefa_breaker:
        bne             s11, s10, loopdgefa_start
        ret
