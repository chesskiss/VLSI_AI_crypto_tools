// Replacement for newlib's printf().
// Adapted from avr-libc 1.7.0.

/* Copyright (c) 2002, Alexander Popov (sasho@vip.bg)
   Copyright (c) 2002,2004,2005 Joerg Wunsch
   Copyright (c) 2005, Helmut Wallner
   Copyright (c) 2007, Dmitry Xmelkov
   All rights reserved.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

   * Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
   * Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in
     the documentation and/or other materials provided with the
     distribution.
   * Neither the name of the copyright holders nor the names of
     contributors may be used to endorse or promote products derived
     from this software without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
  POSSIBILITY OF SUCH DAMAGE.
*/

#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <assert.h>

/*
 * This file can be compiled into more than one flavour.  The default
 * is to offer the usual modifiers and integer formatting support
 * (level 2).  Level 1 maintains a minimal version that just offers
 * integer formatting, but no modifier support whatsoever.  Level 3 is
 * intented for floating point support.
 *
 * Currently floating point level cannot be enabled, pending __ftoa_engine
 * implementation if anyone cares.
 */

/* values for PRINTF_LEVEL */
#define PRINTF_MIN 1
#define PRINTF_STD 2
#define PRINTF_FLT 3

#ifndef PRINTF_LEVEL
# define PRINTF_LEVEL PRINTF_STD
#endif

#if PRINTF_LEVEL == PRINTF_MIN || PRINTF_LEVEL == PRINTF_STD \
    || PRINTF_LEVEL == PRINTF_FLT
/* OK */
#else
# error "Not a known printf level."
#endif

// A simplified model of FILE, used internally only.
struct Stream {
    int   len;          // number of characters printed
    int   size;         // size of output buffer for snprintf()
    char *buf;          // output buffer for snprintf()
};

// Output a character into a stream, which is either a memory buffer for
// snprintf(), or UART for printf().
static void stream_putc(char c, struct Stream *stream)
{
    if (stream->buf) {
        if (stream->len < stream->size)
            *stream->buf++ = c;
    } else
        putchar(c);
    stream->len++;
}

#define GETBYTE(x, y, fmt)      (*fmt++)

// Convert number to string in reverse order.
// The string will not be nul terminated.
// Hex is produced in uppercase if base is ored with XTOA_UPPER.
// Return pointer to the first byte after the last character.
#define XTOA_UPPER      0x100
static char * __ultoa_invert (unsigned long val, char *s, int base)
{
    unsigned letter = base & XTOA_UPPER ? 'A' - '0' - 10 : 'a' - '0' - 10;
    base &= XTOA_UPPER - 1;
    do {
        unsigned rem = val % base;
        if (rem > 9)
            rem += letter;
        *s++ = rem + '0';
        val /= base;
    } while (val);

    return s;
}

/* -------------------------------------------------------------------- */
#if PRINTF_LEVEL <= PRINTF_MIN

#define FL_ALTHEX       0x04
#define FL_ALT          0x10
#define FL_ALTLWR       0x20
#define FL_NEGATIVE     0x40
#define FL_LONG         0x80

static int vfprintf(struct Stream *stream, const char *fmt, va_list ap)
{
    unsigned char c;        /* holds a char from the format string */
    unsigned char flags;
    unsigned char buf[11];  /* size for -1 in octal, without '\0'  */

    stream->len = 0;

    for (;;) {

	for (;;) {
	    c = GETBYTE (stream->flags, __SPGM, fmt);
	    if (!c) goto ret;
	    if (c == '%') {
		c = GETBYTE (stream->flags, __SPGM, fmt);
		if (c != '%') break;
	    }
	    stream_putc (c, stream);
	}

	for (flags = 0;
	     !(flags & FL_LONG);	/* 'll' will detect as error	*/
	     c = GETBYTE (stream->flags, __SPGM, fmt))
	{
	    if (c && strchr(" +-.0123456789h", c))
		continue;
	    if (c == '#') {
		flags |= FL_ALT;
		continue;
	    }
	    if (c == 'l') {
		flags |= FL_LONG;
		continue;
	    }
	    break;
	}

	/* Only a format character is valid.	*/

	if (c && strchr("EFGefg", c)) {
	    (void) va_arg (ap, double);
	    stream_putc ('?', stream);
	    continue;
	}

	{
	    const char * pnt;

	    switch (c) {

	      case 'c':
		stream_putc (va_arg (ap, int), stream);
		continue;

	      case 's':
		pnt = va_arg (ap, char *);
	        while ( (c = GETBYTE (flags, FL_PGMSTRING, pnt)) != 0)
		    stream_putc (c, stream);
		continue;
	    }
	}

	if (c == 'd' || c == 'i') {
	    long x = (flags & FL_LONG) ? va_arg(ap,long) : va_arg(ap,int);
	    flags &= ~FL_ALT;
	    if (x < 0) {
		x = -x;
		/* `stream_putc ('-', stream)' will considarably inlarge stack size.
		   So flag is used.	*/
		flags |= FL_NEGATIVE;
	    }
	    c = __ultoa_invert (x, (char *)buf, 10) - (char *)buf;

	} else {
	    int base;

	    switch (c) {
	      case 'u':
		flags &= ~FL_ALT;
	        base = 10;
		goto ultoa;
	      case 'o':
	        base = 8;
		goto ultoa;
	      case 'p':
	        flags |= FL_ALT;
		/* no break */
	      case 'x':
		flags |= (FL_ALTHEX | FL_ALTLWR);
	        base = 16;
		goto ultoa;
	      case 'X':
		flags |= FL_ALTHEX;
	        base = 16 | XTOA_UPPER;
	      ultoa:
		c = __ultoa_invert ((flags & FL_LONG)
				    ? va_arg(ap, unsigned long)
				    : va_arg(ap, unsigned int),
				    (char *)buf, base)  -  (char *)buf;
		break;

	      default:
	        goto ret;
	    }
	}

	/* Integer number output.	*/
	if (flags & FL_NEGATIVE)
	    stream_putc ('-', stream);
	if ((flags & FL_ALT) && (buf[c-1] != '0')) {
	    stream_putc ('0', stream);
	    if (flags & FL_ALTHEX)
#if  FL_ALTLWR != 'x' - 'X'
# error
#endif
		stream_putc ('X' + (flags & FL_ALTLWR), stream);
	}
	do {
	    stream_putc (buf[--c], stream);
	} while (c);

    } /* for (;;) */

  ret:
    return stream->len;
}

/* --------------------------------------------------------------------	*/
#else	/* i.e. PRINTF_LEVEL > PRINTF_MIN */

#define FL_ZFILL	0x01
#define FL_PLUS		0x02
#define FL_SPACE	0x04
#define FL_LPAD		0x08
#define FL_ALT		0x10
#define FL_WIDTH	0x20
#define FL_PREC		0x40
#define FL_LONG		0x80

#define FL_NEGATIVE	FL_LONG

#define FL_ALTUPP	FL_PLUS
#define FL_ALTHEX	FL_SPACE

#define	FL_FLTUPP	FL_ALT
#define FL_FLTEXP	FL_PREC
#define	FL_FLTFIX	FL_LONG

static int vfprintf(struct Stream *stream, const char *fmt, va_list ap)
{
    unsigned char c;		/* holds a char from the format string */
    unsigned char flags;
    unsigned char width;
    unsigned char prec;
    unsigned char buf[11];	/* size for -1 in octal, without '\0'	*/

    stream->len = 0;

    for (;;) {

	for (;;) {
	    c = GETBYTE (stream->flags, __SPGM, fmt);
	    if (!c) goto ret;
	    if (c == '%') {
		c = GETBYTE (stream->flags, __SPGM, fmt);
		if (c != '%') break;
	    }
	    stream_putc (c, stream);
	}

	flags = 0;
	width = 0;
	prec = 0;

	do {
	    if (flags < FL_WIDTH) {
		switch (c) {
		  case '0':
		    flags |= FL_ZFILL;
		    continue;
		  case '+':
		    flags |= FL_PLUS;
		    /* FALLTHROUGH */
		  case ' ':
		    flags |= FL_SPACE;
		    continue;
		  case '-':
		    flags |= FL_LPAD;
		    continue;
		  case '#':
		    flags |= FL_ALT;
		    continue;
		}
	    }

	    if (flags < FL_LONG) {
		if (c >= '0' && c <= '9') {
		    c -= '0';
		    if (flags & FL_PREC) {
			prec = 10*prec + c;
			continue;
		    }
		    width = 10*width + c;
		    flags |= FL_WIDTH;
		    continue;
		}
		if (c == '.') {
		    if (flags & FL_PREC)
			goto ret;
		    flags |= FL_PREC;
		    continue;
		}
		if (c == 'l') {
		    flags |= FL_LONG;
		    continue;
		}
		if (c == 'h')
		    continue;
	    }

	    break;
	} while ( (c = GETBYTE (stream->flags, __SPGM, fmt)) != 0);

	/* Only a format character is valid.	*/

#if	'F' != 'E'+1  ||  'G' != 'F'+1  ||  'f' != 'e'+1  ||  'g' != 'f'+1
# error
#endif

#if PRINTF_LEVEL >= PRINTF_FLT
	if (c >= 'E' && c <= 'G') {
	    flags |= FL_FLTUPP;
	    c += 'e' - 'E';
	    goto flt_oper;

	} else if (c >= 'e' && c <= 'g') {

	    int exp;		/* exponent of master decimal digit	*/
	    int n;
	    unsigned char vtype;	/* result of float value parse	*/
	    unsigned char sign;		/* sign character (or 0)	*/
# define ndigs	c		/* only for this block, undef is below	*/

	    flags &= ~FL_FLTUPP;

	  flt_oper:
	    if (!(flags & FL_PREC))
		prec = 6;
	    flags &= ~(FL_FLTEXP | FL_FLTFIX);
	    if (c == 'e')
		flags |= FL_FLTEXP;
	    else if (c == 'f')
		flags |= FL_FLTFIX;
	    else if (prec > 0)
		prec -= 1;

	    if (flags & FL_FLTFIX) {
		vtype = 7;		/* 'prec' arg for 'ftoa_engine'	*/
		ndigs = prec < 60 ? prec + 1 : 60;
	    } else {
		if (prec > 7) prec = 7;
		vtype = prec;
		ndigs = 0;
	    }
	    exp = __ftoa_engine (va_arg(ap,double), (char *)buf, vtype, ndigs);
	    vtype = buf[0];

	    sign = 0;
	    if ((vtype & FTOA_MINUS) && !(vtype & FTOA_NAN))
		sign = '-';
	    else if (flags & FL_PLUS)
		sign = '+';
	    else if (flags & FL_SPACE)
		sign = ' ';

	    if (vtype & (FTOA_NAN | FTOA_INF)) {
		const char *p;
		ndigs = sign ? 4 : 3;
		if (width > ndigs) {
		    width -= ndigs;
		    if (!(flags & FL_LPAD)) {
			do {
			    stream_putc (' ', stream);
			} while (--width);
		    }
		} else {
		    width = 0;
		}
		if (sign)
		    stream_putc (sign, stream);
		p = PSTR("inf");
		if (vtype & FTOA_NAN)
		    p = PSTR("nan");
# if ('I'-'i' != 'N'-'n') || ('I'-'i' != 'F'-'f') || ('I'-'i' != 'A'-'a')
#  error
# endif
		while ( (ndigs = pgm_read_byte(p)) != 0) {
		    if (flags & FL_FLTUPP)
			ndigs += 'I' - 'i';
		    stream_putc (ndigs, stream);
		    p++;
		}
		goto tail;
	    }

	    /* Output format adjustment, number of decimal digits in buf[] */
	    if (flags & FL_FLTFIX) {
		ndigs += exp;
		if ((vtype & FTOA_CARRY) && buf[1] == '1')
		    ndigs -= 1;
		if ((signed char)ndigs < 1)
		    ndigs = 1;
		else if (ndigs > 8)
		    ndigs = 8;
	    } else if (!(flags & FL_FLTEXP)) {		/* 'g(G)' format */
		if (exp <= prec && exp >= -4)
		    flags |= FL_FLTFIX;
		while (prec && buf[1+prec] == '0')
		    prec--;
		if (flags & FL_FLTFIX) {
		    ndigs = prec + 1;		/* number of digits in buf */
		    prec = prec > exp
			   ? prec - exp : 0;	/* fractional part length  */
		}
	    }

	    /* Conversion result length, width := free space length	*/
	    if (flags & FL_FLTFIX)
		n = (exp>0 ? exp+1 : 1);
	    else
		n = 5;		/* 1e+00 */
	    if (sign) n += 1;
	    if (prec) n += prec + 1;
	    width = width > n ? width - n : 0;

	    /* Output before first digit	*/
	    if (!(flags & (FL_LPAD | FL_ZFILL))) {
		while (width) {
		    stream_putc (' ', stream);
		    width--;
		}
	    }
	    if (sign) stream_putc (sign, stream);
	    if (!(flags & FL_LPAD)) {
		while (width) {
		    stream_putc ('0', stream);
		    width--;
		}
	    }

	    if (flags & FL_FLTFIX) {		/* 'f' format		*/

		n = exp > 0 ? exp : 0;		/* exponent of left digit */
		do {
		    if (n == -1)
			stream_putc ('.', stream);
		    flags = (n <= exp && n > exp - ndigs)
			    ? buf[exp - n + 1] : '0';
		    if (--n < -prec)
			break;
		    stream_putc (flags, stream);
		} while (1);
		if (n == exp
		    && (buf[1] > '5'
		        || (buf[1] == '5' && !(vtype & FTOA_CARRY))) )
		{
		    flags = '1';
		}
		stream_putc (flags, stream);

	    } else {				/* 'e(E)' format	*/

		/* mantissa	*/
		if (buf[1] != '1')
		    vtype &= ~FTOA_CARRY;
		stream_putc (buf[1], stream);
		if (prec) {
		    stream_putc ('.', stream);
		    sign = 2;
		    do {
			stream_putc (buf[sign++], stream);
		    } while (--prec);
		}

		/* exponent	*/
		stream_putc (flags & FL_FLTUPP ? 'E' : 'e', stream);
		ndigs = '+';
		if (exp < 0 || (exp == 0 && (vtype & FTOA_CARRY) != 0)) {
		    exp = -exp;
		    ndigs = '-';
		}
		stream_putc (ndigs, stream);
		for (ndigs = '0'; exp >= 10; exp -= 10)
		    ndigs += 1;
		stream_putc (ndigs, stream);
		stream_putc ('0' + exp, stream);
	    }

	    goto tail;
# undef ndigs
	}

#else		/* to: PRINTF_LEVEL >= PRINTF_FLT */
	if ((c >= 'E' && c <= 'G') || (c >= 'e' && c <= 'g')) {
	    (void) va_arg (ap, double);
	    buf[0] = '?';
	    goto buf_addr;
	}

#endif

	{
	    const char * pnt;
	    size_t size;

	    switch (c) {

	      case 'c':
		buf[0] = va_arg (ap, int);
#if  PRINTF_LEVEL < PRINTF_FLT
	      buf_addr:
#endif
		pnt = (char *)buf;
		size = 1;
		goto str_lpad;

	      case 's':
		pnt = va_arg (ap, char *);
		size = strnlen (pnt, (flags & FL_PREC) ? prec : ~0);

	      str_lpad:
		if (!(flags & FL_LPAD)) {
		    while (size < width) {
			stream_putc (' ', stream);
			width--;
		    }
		}
		while (size) {
		    stream_putc (GETBYTE (flags, FL_PGMSTRING, pnt), stream);
		    if (width) width -= 1;
		    size -= 1;
		}
		goto tail;
	    }
	}

	if (c == 'd' || c == 'i') {
	    long x = (flags & FL_LONG) ? va_arg(ap,long) : va_arg(ap,int);
	    flags &= ~(FL_NEGATIVE | FL_ALT);
	    if (x < 0) {
		x = -x;
		flags |= FL_NEGATIVE;
	    }
	    c = __ultoa_invert (x, (char *)buf, 10) - (char *)buf;

	} else {
	    int base;

	    if (c == 'u') {
		flags &= ~FL_ALT;
		base = 10;
		goto ultoa;
	    }

	    flags &= ~(FL_PLUS | FL_SPACE);

	    switch (c) {
	      case 'o':
	        base = 8;
		goto ultoa;
	      case 'p':
	        flags |= FL_ALT;
		/* no break */
	      case 'x':
		if (flags & FL_ALT)
		    flags |= FL_ALTHEX;
	        base = 16;
		goto ultoa;
	      case 'X':
		if (flags & FL_ALT)
		    flags |= (FL_ALTHEX | FL_ALTUPP);
	        base = 16 | XTOA_UPPER;
	      ultoa:
		c = __ultoa_invert ((flags & FL_LONG)
				    ? va_arg(ap, unsigned long)
				    : va_arg(ap, unsigned int),
				    (char *)buf, base)  -  (char *)buf;
		flags &= ~FL_NEGATIVE;
		break;

	      default:
	        goto ret;
	    }
	}

	{
	    unsigned char len;

	    len = c;
	    if (flags & FL_PREC) {
		flags &= ~FL_ZFILL;
		if (len < prec) {
		    len = prec;
		    if ((flags & FL_ALT) && !(flags & FL_ALTHEX))
			flags &= ~FL_ALT;
		}
	    }
	    if (flags & FL_ALT) {
		if (buf[c-1] == '0') {
		    flags &= ~(FL_ALT | FL_ALTHEX | FL_ALTUPP);
		} else {
		    len += 1;
		    if (flags & FL_ALTHEX)
		    	len += 1;
		}
	    } else if (flags & (FL_NEGATIVE | FL_PLUS | FL_SPACE)) {
		len += 1;
	    }

	    if (!(flags & FL_LPAD)) {
		if (flags & FL_ZFILL) {
		    prec = c;
		    if (len < width) {
			prec += width - len;
			len = width;
		    }
		}
		while (len < width) {
		    stream_putc (' ', stream);
		    len++;
		}
	    }

	    width =  (len < width) ? width - len : 0;

	    if (flags & FL_ALT) {
		stream_putc ('0', stream);
		if (flags & FL_ALTHEX)
		    stream_putc (flags & FL_ALTUPP ? 'X' : 'x', stream);
	    } else if (flags & (FL_NEGATIVE | FL_PLUS | FL_SPACE)) {
		unsigned char z = ' ';
		if (flags & FL_PLUS) z = '+';
		if (flags & FL_NEGATIVE) z = '-';
		stream_putc (z, stream);
	    }

	    while (prec > c) {
		stream_putc ('0', stream);
		prec--;
	    }

	    do {
		stream_putc (buf[--c], stream);
	    } while (c);
	}

      tail:
	/* Tail is possible.	*/
	while (width) {
	    stream_putc (' ', stream);
	    width--;
	}
    } /* for (;;) */

  ret:
    return stream->len;
}
#endif	/* PRINTF_LEVEL > PRINTF_MIN */

int printf(const char *fmt, ...)
{
    va_list ap;
    struct Stream stream;
    int i;

    stream.buf = 0;

    va_start(ap, fmt);
    i = vfprintf(&stream, fmt, ap);
    va_end(ap);

    return i;
}

int snprintf(char *buf, size_t size, const char *fmt, ...)
{
    va_list ap;
    struct Stream stream;
    int i;

    if (!buf)
        return 0;

    stream.buf = buf;
    stream.size = size - 1;

    va_start(ap, fmt);
    i = vfprintf(&stream, fmt, ap);
    va_end(ap);

    if (size)
        buf[stream.len < stream.size ? stream.len : stream.size] = 0;

    return i;
}

int puts(const char *str)
{
	while (*str) {
		putchar(*str++);
	}

	return putchar('\n');
}
