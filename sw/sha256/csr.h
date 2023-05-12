 
#ifndef CSR_H_
#define CSR_H_
 
#define csr_read(csr)                                           \
	({                                                              \
	         register unsigned long __v;                             \
		         __asm__ volatile ("csrr %0, " #csr                      \
					                                 : "=r" (__v));                  \
									         __v;                                                    \
										 })
 
#define csr_write(csr, val)                                     \
	({                                                              \
	         unsigned long __v = (unsigned long)(val);               \
		         __asm__ volatile ("csrw " #csr ", %0"                   \
					                                 : : "rK" (__v)                  \
									                                 : "memory");                    \
													 })
 
 
#endif /* CSR_H_ */
