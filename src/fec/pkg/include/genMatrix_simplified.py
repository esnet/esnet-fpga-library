import galois
import numpy as np
import random
import itertools

np.set_printoptions(formatter={'int':lambda x: f'{x:2}'},linewidth = 1000)

#GF = galois.GF(8,irreducible_poly=[1,0,1,1])
GF = galois.GF(16,irreducible_poly=[1,0,0,1,1])
#GF = galois.GF(32,irreducible_poly=[1,0,0,1,0,1])
#GF = galois.GF(64,irreducible_poly=[1,0,0,0,0,1,1])
#GF = galois.GF(256,irreducible_poly=[1,0,0,0,1,1,0,1,1])

print(GF.properties)
print(GF.repr_table())

#--------------------------------------------------------------------------------------
# Galois Field Functions from scratch
#--------------------------------------------------------------------------------------
alpha = GF.primitive_element
#gf_mul_seq =  [1,2,4,8,3,6,12,11,5,10,7,14,15,13,9,0]
gf_mul_seq = []
for i in range(GF.order):
   if i < GF.order-1: gf_mul_seq.append(int(alpha**i))
   else             : gf_mul_seq.append(int(0))

print("------   GF elements (ordered by power)  -------")
print(gf_mul_seq)
print("-------------------------------------------")

gf_log_seq = {}
gf_exp_seq = {}

for i,val in enumerate(gf_mul_seq) :
   gf_log_seq[i] = val     # alpha -> x 
   gf_exp_seq[val] = i     # x -> alpha
   
print("------   GF Log Table from scratch  -------")
print("gf log seq",gf_log_seq)
print("gf exp seq",gf_exp_seq)
print("-------------------------------------------")

def gf_mul(a,b):
  if (a == 0) or (b == 0):
     return 0
  
  exp_a = gf_exp_seq[a]
  exp_b = gf_exp_seq[b]
  sum = (exp_a+exp_b) % (GF.order-1)
  return(gf_log_seq[sum])

def gf_div(a,b):
  if ( a == 0) or (b == 0):
     return 0

  exp_a = gf_exp_seq[a]
  exp_b = gf_exp_seq[b]
  sum = (exp_a-exp_b)
  if (sum < 0): sum = sum + (GF.order-1)
  sum = sum % (GF.order-1)
  return(gf_log_seq[sum])

def gf_sum(a,b):
   return a^b

#--------------------------------------------------------------------------------------
# Polynomial Functions
#--------------------------------------------------------------------------------------

def poly_sum(poly_a,poly_b):
   return [ gf_sum(a,b) for a,b in zip(poly_a,poly_b)]

def poly_had_mul(poly_a,poly_b):
   return [ gf_mul(a,b) for a,b in zip(poly_a,poly_b)]

def poly_scale(poly_a,s):
   return [ gf_mul(x,s) for x in poly_a]

def poly_mul(poly_a,poly_b):
   partial_product = [0 for x in poly_a]
   for b_term in reversed(poly_b):
#      print(poly_a,"x",b_term , " " , partial_product, "+", poly_scale(poly_a,b_term))
      partial_product = poly_sum([0]+partial_product,poly_scale(poly_a,b_term))
      poly_a.append(0)
   return partial_product

# dot product of 2 vectors over GF
def poly_elem_mul(poly_a,poly_b):
   return [ gf_mul(a,b) for a,b in zip(poly_a,poly_b) ]

def poly_div(poly_a,poly_b):

   divisor = []
   partial_remainder = poly_a
   partial_product = poly_b + [0]*(len(poly_a)-len(poly_b))

   while (len(partial_remainder) >= len(poly_b)) :
      scale = gf_div(partial_remainder[0],poly_b[0])
#      print(partial_remainder)
      partial_remainder = poly_sum(partial_remainder,poly_scale(partial_product,scale))
#      print(f'{poly_scale(partial_product,scale)} \t {partial_product} x {scale}')
#      print("--------------")
      partial_remainder = partial_remainder[1::]
      partial_product   = partial_product[0:-1]
      divisor.append(scale)

   return divisor,partial_remainder


#--------------------------------------------------------------------------------------
# Reed Solomon Functions
#--------------------------------------------------------------------------------------

# Create the RS generator polynomial
def rs_gen_poly(t):
   g = [1]
   for a in range(1,2*t+1):
      g = poly_mul(g,[1,gf_log_seq[a]])
   return g

# Create the RS generator matrix
def rs_gen_G(k,t,gen_poly):   
   n = k + 2*t
   print(
      f"""
        The parity check words are the remainder of the identity matrix
        divided by the generator polynomial.  This gives us a G matrix
        in the form of an identity matrix + parity generation words for
        directly passing the data (n) bits into the m = (n+2*t) matrix
       """
   )
   print(f"n = {n} k = {k} 2t = {2*t}")
   row = [1] + [0]*(n-1)
   G = []
   for K in range(0,k):
      G.append(row.copy())      
      div,rem = (poly_div(G[-1],gen_poly))
      print(f"G[-1] = {G[-1]} div={div} rem={rem}")
      G[-1] = G[-1][0:k]+rem
      row = [0] + row[0:n-1]
   G = np.array(G)
   print(f"G=\n{G}")
   return G

def rs_gen_H(G):
   k,n = G.shape
   p = n-k
   print(f'G has {n} cols and {k} rows')
   P = G[0:k,k:n]
   I = np.identity(p,dtype=int)
   H = np.concatenate((P,I)).transpose()
   return(H)

def poly_dot(X,Y):
   if (len(X) != len(Y)): return -1
   Z = poly_elem_mul(X,Y)
   p = 0
   for z in Z:
      p = gf_sum(p,z)
   return p


"""
def poly_matrix_invert(G):
   print("Inverting G = ")
   print(G)
   G = np.concatenate((G, np.identity(len(G),dtype=int)),axis=1)
   print("Inverting G = ")
   print(G)
   H = poly_gauss_jordan(G)
   return H
"""

def poly_matrix_vector_mul(M,V):
   if (len(M[0]) != len(V)):
      # print(f"Error vector length does not match matrix row length")
      # print(f"  Mrow = {len(M[0])}  V={len(V)}")
      return [-1]

   y = []
   for row in M:
      y.append(poly_dot(row,V))
   return y

def gf_poly_matrix_determinant(M):
#   print(" Calculate determinant ")
#   print(M)

   det_fwd = [1]*len(M)
   det_rev = [1]*len(M)

   for col in range(0,len(M)) :
      for j in range(0,len(M)):
         row = (j+col) % len(M)
#         print(f" {col},{row}",end = " ")

#      print("|",end=" ")
         
      for j in range(len(M),0,-1) :
         row = (j-col+len(M)) % len(M)
#         print(f" {col},{row}",end = " ")

#      print()

#   print()
   for col in range(0,len(M)) :
      for j in range(0,len(M)):
         row = (j+col) % len(M)
#         print(f" {M[col][row]:3}",end = " ")
         det_fwd[j] = gf_mul(det_fwd[j],M[col][row])         

#      print("|",end=" ")

      for j in range(len(M),0,-1) :         
         row = (j-col+len(M)) % len(M)
#         print(f" {M[col][row]:3}",end = " ")
         det_rev[j-1] = gf_mul(det_rev[j-1],M[col][row])         

#      print(f"det_fwd {str(det_fwd):<25} det_rev {str(det_rev):<25}")

#   print(f"det_fwd = {det_fwd}")
#   print(f"det_rev = {det_rev}")
   #-------------------------------------------------------------------
   # shortcut to det ( assuming at least 2 rows of the form:
   #
   # ( 0..0 1 0 0..0 )
   # ( 0..0 0 1 0..0 )
   #
   # only the primary diagonal is non zero.
   # if just one such row exists, then both diagonals can be non zero.
   # if no such rows exist, then all diagonals have to be considered.
   #
   # since the co-factors calculation removes a row, we need to be careful
   # that there are 2 such rows left over AFTER picking a minor matrix
   #-------------------------------------------------------------------      
   
   col = 0
   det = 1
   for j in range(0,len(M)) :
      row = (j+col) % len(M)
      det = gf_mul(det,M[row][row])
   return det

def gf_poly_matrix_invert(G):
   A = GF(G)
   A_inv = np.linalg.inv(A)
   return A_inv

def poly_matrix_invert(M):

   """
   M = np.array([[10,10,10],
                 [ 0, 1, 0],
                 [ 0, 0, 1]])
   """
   
   # ---- Use the method of sherman morrison

   A = M[0:len(M)-1,0:len(M)-1]
   B = M[0:len(M)-1,len(M)-1]
   C = M[len(M)-1,0:len(M)-1]
   D = M[len(M)-1:,len(M)-1:]

   Dinv  = np.linalg.inv(D)
   BDinv = B*Dinv
   BDinvC = BDinv*C
   AmBDinvC = A-BDinvC
   
   print ("sherman morrison inverse ")
   print(f"M\n{M}")
   print(f"A\n{A}")
   print(f"B\n{B}")
   print(f"C\n{C}")
   print(f"D\n{D}")
   print(f"Din\n{Dinv}")
   print(f"BDinv\n{BDinv}")
   print(f"BDinvC\n{BDinvC}")   
   print(f"AmBDinvC\n{AmBDinvC}")   
   
def rs_poly_encode(Gpoly,m):
   t = len(Gpoly) - 1
   c = m + [0]*t

   div,rem = poly_div(c,Gpoly)
   return m+rem

def rs_encode(G,m):
   print("RS Encoding --- G = ")
   for row in G:
      print(row)
   print(f"Using ... m = {m}")

   print(G.transpose())
   p = poly_matrix_vector_mul(G.transpose(),m)
   print(f" encode  Grow = {len(G.transpose()[0])}  m={len(m)} p={p}")      
   
   return p

def rs_decode(H,m):
   print(f" decode  len Hrow = {len(H[0])}  m={len(m)}")
   print(f"   H = ")
   print(f"{H}")
   print(f"m = {m}")
   return poly_matrix_vector_mul(H,m)


# ---------------------------- Main --------------------------------------

if (True) :
   print(f'--- testing GF arithmetic with python standard library ---')
   x = GF([2])
   y = GF([7])
   print(f'{x}+{y} = {x+y}')
   print(f'{x}*{y} = {x*y}')
   print(f'{x}/{y} = {x/y}')
   print(f'{x}%{y} = {x%y}')

   print(f'--- testing GF multipy table with python standard library ---')
   gf_mul_lut=[]
   for i in range(GF.order):
       row=[]
       for j in range(GF.order):
           x = GF([i])
           y = GF([j])
           z = x*y
           row.append(int(z.item()))
       print(row)
       gf_mul_lut.append(row)

   print(f'--- testing GF division table with python standard library ---')
   gf_div_lut=[]
   for i in range(GF.order):
       row=[]
       for j in range(GF.order):
           x = GF([i])
           y = GF([j])
           if y != 0: z = x/y
           else:      z = GF([0])
           #z = gf_div(x,y)
           row.append(int(z.item()))
           #row.append(int(z))
       print(row)
       gf_div_lut.append(row)

   print(f'--- testing GF addition table with python standard library ---')
   gf_add_lut=[]
   for i in range(GF.order):
       row=[]
       for j in range(GF.order):
           x = GF([i])
           y = GF([j])
           z = x+y
           row.append(int(z.item()))
       print(row)
       gf_add_lut.append(row)

   print(f'--- testing GF arithmetic with custom library  ---')
   x = 2
   y = 7
   print(f'{x}+{y} = {gf_sum(x,y)}')
   print(f'{x}*{y} = {gf_mul(x,y)}')
   print(f'{x}/{y} = {gf_div(x,y)}')
   # print(f'{x}%{y} = {x%y}')


if (False) :
   print("-----  POLY sum -----")
   poly1 = [ 1, 4, 5, 6 ]
   poly2 = [ 4, 5, 9, 0xF ]
   
   print(f'a = {poly1}')
   print(f'b = {poly2}')
   print(f's = {poly_sum(poly1,poly2)}')
   print()

if (False) :
   print("-----  GF mul / div  -----")
   a = 15
   b = 4
   print(f'a = {a}')
   print(f'b = {b}')
   print(f'mul p = {gf_mul(a,b)}')
   print(f'div d = {gf_div(a,b)}')

if (False) :
   print("-----  POLY Mul -----")

   poly1 = [ 1, 6, 3 ]
   poly2 = [ 6 ]

   print(f'a = {poly1}')
   print(f'b = {poly2}')
   print(f'{poly1} x {poly2} = {poly_mul(poly1,poly2)}')
   print(f'6x3 = {poly_mul([6],[3])}')

if (False) :
   print("-----  POLY Div -----")

   poly1 = [ 1,0,7,6]
   poly2 = [ 1,6,3 ]

   print(f'a = {poly1}')
   print(f'b = {poly2}')
   divisor,remainder = poly_div(poly1,poly2)
   print(f'd = { divisor } , r = { remainder }')

   for x in range(0,4):
      for y in range(0,4):
         poly_x = poly_scale([1,2,3,4],x)
         poly_y = poly_scale([1,2,3,4],y)

         gal_x = galois.Poly(poly_x,field=GF)
         gal_y = galois.Poly(poly_y,field=GF)
      
         print(f'{poly_x}\tx\t{poly_y}\t= {poly_mul(poly_x,poly_y)} \t {gal_x*gal_y}')


if (True) :
   print("-----  Reed Solomon Testing  -----")


   if (True) :
      print("-----  Generator Polynomial Testing  -----\n")
      print(
        f"""
        We should see polynomials with order 2*t + 1
        all parity check polynomial remainders will be of order 2*t
        which is the number of parity words to correct t errors or 2*t erasures
        """
      )

      t = 4 ; print(f'for t={t} errors Gpoly={rs_gen_poly(t)}')
      t = 1 ; print(f'for t={t} errors Gpoly={rs_gen_poly(t)}')
      t = 2 ; print(f'for t={t} errors Gpoly={rs_gen_poly(t)}')
      print()

      print("-----  Generator Matrix Construction -----\n")

   d = [1,2,3,4,5,6,7,8]    # use this to define a specific message else a random one will be generated
   t = 1                    # 2*t parity words for 2*t erasure correction

   try : d
   except :
     n = 8   # number of data symbols. n SHOULD be >= 3 for fast determinant calculation
     d = [random.randrange(0, GF.order, 1) for i in range(n)]
   else :
     n = len(d)
      
   print(f"t = {t} , Data = {d}")
   Gpoly = rs_gen_poly(t)

   print(f"d = {d} t = {t} Gpoly = {Gpoly}\n")
   G = rs_gen_G(len(d),t,Gpoly)
   print("G = ")
   print(G,"\n")

   print("-----  RS Encoder testing  -----")

   print(f"matrix (G) based encoder: message d = {d} t = {t}")
   c_matrix  = rs_encode(G,d)
   c_polydiv = rs_poly_encode(Gpoly,d)

   print(f"encoded message using G matrix   = {c_matrix}")
   print(f"encoded message using Gpoly      = {c_polydiv}")

   print("-----  RS Decoder  -----")

   print("#-- Test to see if all possible G* -> H matrices are invertable --")
   
   print("testing for matrix invertability")
   H_LUT = []
   ERR_LOC_LUT = []
   for errors in itertools.combinations(list(range(0,len(c_matrix))),2*t) :
      e_bits = list(errors)

      c_rx = c_matrix.copy()
      for error in e_bits:
         c_rx[error] = 0

      G_error = G.copy()
      G_error = np.delete(G_error.transpose(),e_bits,0)
      m_rx = np.delete(c_matrix,e_bits)
   
      try :
         H = gf_poly_matrix_invert(G_error)
         H_LUT.append(H)
         ERR_LOC = [1 if i in e_bits else 0 for i in range(len(c_matrix))]
         ERR_LOC_LUT.append(ERR_LOC)
         #print("Iteration:", e_bits)
      except :
         print(f" ----  UNABLE TO INVERT G* ------ ")
         print(f"m_rx = {m_rx}")      
         print(f" Error locations .. {e_bits}")
   
   e_bits = random.sample(range(0, len(c_matrix)), 2*t)    # errors in m,p bits
#   e_bits = random.sample(range(0,len(c_matrix)-2*t),2*t)  # errors in m bits
   print(f" Error locations .. {e_bits}")

   print()
   print("#-- build the G* matrix by deleting errored rows ------- ")
   print()

   c_rx = c_matrix.copy()
   for error in e_bits:
      c_rx[error] = 0

   G_error = G.copy()
   G_error = np.delete(G_error.transpose(),e_bits,0)
   m_rx = np.delete(c_matrix,e_bits)
   print(f"m_rx = {m_rx}")

   print("G* = ")
   print(G_error)
   
   try :
      H = gf_poly_matrix_invert(G_error)
   except :
      print(f" ----  UNABLE TO INVERT G* ------ ")
      print(f" Error locations .. {e_bits}")
      exit()
   
   print("H = ")
   print(H)
   d_corrected = poly_matrix_vector_mul(np.array(H),m_rx)

   print(f" -- message with d and parity, and corrupted message received !")
   print(f"    upto {2*t} erasures can be corrected\n")
   print(f"c_tx   = {np.array(c_matrix)}")
   print(f"c_rx   = {np.array(c_rx)}")
   print(f" -- d sent and d corrected should be the same !")
   print(f"d      = {np.array(d)}")
   print(f"d_corr = {np.array(d_corrected)}")
   print(f"\n")

   print()
   print("#-- build the G* matrix by copying parity row into lost m rows ------- ")
   print("   Note the G and H matrix are different from the method above ")
   print()
   
   c_rx = c_matrix.copy()
   G_error = G.copy()
   G_error = G_error.transpose()
   for i,error in enumerate(e_bits) :
      c_rx[error] = c_rx[len(d)+i]
      G_error[error] = G_error[len(d)+i]
      d_rx = c_rx[0:len(d)]
   G_error = G_error[0:len(d)]
   print(f"d_rx = {d_rx}")

   print("G* = ")
   print(G_error)

   H = gf_poly_matrix_invert(G_error)
   print("H = ")
   print(H)
   
   d_corrected = poly_matrix_vector_mul(np.array(H),d_rx)
   print(f"d      = {np.array(d)}")
   print(f"d_corr = {np.array(d_corrected)}")
   print(f"c_tx   = {np.array(c_matrix)}")
   print(f"c_rx   = {np.array(c_rx)}")

   # ---------------------  Write the C Model for the RS encoder and decoder -----------

if (False) :
   C_Model_File = open("rs_model.h","w")

   print(f''' static const char _ejfat_rs_gf_log_seq[{len(gf_log_seq)}] = {{ {",".join(map(str,list(gf_log_seq.values())))} }}; ''',file = C_Model_File)

   gf_exp_seq_sorted = dict(sorted(gf_exp_seq.items()))
   print(f''' static const char _ejfat_rs_gf_exp_seq[{len(gf_exp_seq_sorted)}] = {{ {",".join(map(str,list(gf_exp_seq_sorted.values())))} }}; ''', file = C_Model_File)

   print(f'static const char _ejfat_rs_gf_mul_table[{GF.order}][{GF.order}] = {{' , file = C_Model_File);
   if GF.order <= 16 :
      for i in range(0,GF.order) :
         row = ', '.join(map(str,[gf_mul(i,j) for j in range(0,GF.order)]))
         print(f''' {{ {row} }} ,''', file = C_Model_File)
   print('};', file = C_Model_File)
   
   print('\n', file = C_Model_File);
   print(f''' static const int _ejfat_rs_n = {n}; // data words ''' , file = C_Model_File);
   print(f''' static const int _ejfat_rs_p = {2*t}; // parity words  ''' , file = C_Model_File);
   print(f''' static const int _ejfat_rs_k = {n+2*t}; // message words = data+parity ''' , file = C_Model_File);   
   
   print(
f'''
 static const char _ejfat_rs_G[{G.shape[0]}][{G.shape[1]}] = {{
{
(","+ chr(10)).join([ "    {" + ",".join(map(str,list(G[i]))) + "}" for i in range(len(G)) ])
} 
 }};
''',
   file = C_Model_File)
   

   # ---------------------  Write the verilog include file for the fec lookup tables ----------------------

if (True) :
   svh_file = open("fec_luts.svh","w")

   print(f"localparam GF_ORDER = {GF.order};", file = svh_file);
   print(f"localparam SYM_SIZE = $clog2(GF_ORDER);\n", file = svh_file);

   print(f'''localparam logic [SYM_SIZE-1:0] GF_LOG_LUT [GF_ORDER] =
    '{{ {",".join(map(str,list(gf_log_seq.values())))} }};\n''', file = svh_file);

   gf_exp_seq_sorted = dict(sorted(gf_exp_seq.items()))
   print(f'''localparam logic [SYM_SIZE-1:0] GF_EXP_LUT [GF_ORDER] =
    '{{ {",".join(map(str,list(gf_exp_seq_sorted.values())))} }};\n''', file = svh_file);

   print(f'''localparam logic [SYM_SIZE-1:0] GF_MUL_LUT [GF_ORDER][GF_ORDER] = '{{''', file = svh_file);
   for row in range(len(gf_mul_lut)):
      if row < len(gf_mul_lut)-1:
          print(f'''    '{{ {",".join(map(str,gf_mul_lut[row]))} }},''', file = svh_file);
      else: # last row, no comma.
          print(f'''    '{{ {",".join(map(str,gf_mul_lut[row]))} }}''', file = svh_file);
   print(f'''}};\n''', file = svh_file);

   print(f'''localparam logic [SYM_SIZE-1:0] GF_DIV_LUT [GF_ORDER][GF_ORDER] = '{{''', file = svh_file);
   for row in range(len(gf_div_lut)):
      if row < len(gf_div_lut)-1:
          print(f'''    '{{ {",".join(map(str,gf_div_lut[row]))} }},''', file = svh_file);
      else: # last row, no comma.
          print(f'''    '{{ {",".join(map(str,gf_div_lut[row]))} }}''', file = svh_file);
   print(f'''}};\n''', file = svh_file);

   print(f'''localparam logic [SYM_SIZE-1:0] GF_ADD_LUT [GF_ORDER][GF_ORDER] = '{{''', file = svh_file);
   for row in range(len(gf_add_lut)):
      if row < len(gf_add_lut)-1:
          print(f'''    '{{ {",".join(map(str,gf_add_lut[row]))} }},''', file = svh_file);
      else: # last row, no comma.
          print(f'''    '{{ {",".join(map(str,gf_add_lut[row]))} }}''', file = svh_file);
   print(f'''}};\n''', file = svh_file);

   print(f"localparam RS_N  = {len(d)+2*t};", file = svh_file);
   print(f"localparam RS_K  = {len(d)};", file = svh_file);
   print(f"localparam RS_2T = {2*t};\n", file = svh_file);

   print(f'''localparam logic [RS_2T:0][SYM_SIZE-1:0] RS_G_POLY = '{{ {",".join(map(str,Gpoly[::-1]))} }};\n''',
         file = svh_file);

   print(f'''localparam logic [SYM_SIZE-1:0] RS_G_LUT [RS_K][RS_N] = '{{''', file = svh_file);
   for row in range(len(G)):
      if row < len(G)-1:
          print(f'''    '{{ {",".join(map(str,G[row]))} }},''', file = svh_file);
      else: # last row, no comma.
          print(f'''    '{{ {",".join(map(str,G[row]))} }}''', file = svh_file);
   print(f'''}};\n''', file = svh_file);

   print(f'''localparam NUM_H = {len(H_LUT)};\n''', file = svh_file);

   print(f'''localparam logic [0:NUM_H-1][0:RS_K-1][0:RS_K-1][SYM_SIZE-1:0] RS_H_LUT = '{{''', file = svh_file);
   print(f'''    '{{''', file = svh_file);
   for item in range(len(H_LUT)):
      for row in range(len(H_LUT[item])):
         if row < len(H_LUT[item])-1:
             print(f'''        '{{ {",".join(map(str,H_LUT[item][row]))} }},''', file = svh_file);
         else: # last row, no comma.
             print(f'''        '{{ {",".join(map(str,H_LUT[item][row]))} }}''', file = svh_file);
      if item < len(H_LUT)-1: print(f'''    }}, '{{''', file = svh_file);
      else:        print(f'''    }}''',      file = svh_file);  # last row, no comma.
   print(f'''}};\n''', file = svh_file);

   print(f'''localparam logic [0:NUM_H-1][0:RS_N-1] RS_ERR_LOC_LUT = '{{''', file = svh_file);
   for item in range(len(ERR_LOC_LUT)):
      if item < len(ERR_LOC_LUT)-1:
          print(f'''        '{{ {",".join(map(str,ERR_LOC_LUT[item]))} }},''', file = svh_file);
      else:
          print(f'''        '{{ {",".join(map(str,ERR_LOC_LUT[item]))} }}''', file = svh_file);
   print(f'''}};''', file = svh_file);

   svh_file.close()
