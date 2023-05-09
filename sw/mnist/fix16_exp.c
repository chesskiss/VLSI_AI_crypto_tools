#include "include/fix16.h"
#include <stdbool.h>

#define FIXMATH_NO_CACHE

#ifndef FIXMATH_NO_CACHE
static fix16_t _fix16_exp_cache_index[4096]  = { 0 };
static fix16_t _fix16_exp_cache_value[4096]  = { 0 };
#endif



fix16_t fix16_exp(fix16_t inValue) {
	if(inValue == 0        ) return fix16_one;
	if(inValue == fix16_one) return fix16_e;
	if(inValue >= 681391   ) return fix16_maximum;
	if(inValue <= -772243  ) return 0;

	#ifndef FIXMATH_NO_CACHE
	fix16_t tempIndex = (inValue ^ (inValue >> 16));
	tempIndex = (inValue ^ (inValue >> 4)) & 0x0FFF;
	if(_fix16_exp_cache_index[tempIndex] == inValue)
		return _fix16_exp_cache_value[tempIndex];
	#endif
                        
	/* The algorithm is based on the power series for exp(x):
	 * http://en.wikipedia.org/wiki/Exponential_function#Formal_definition
	 * 
	 * From term n, we get term n+1 by multiplying with x/n.
	 * When the sum term drops to zero, we can stop summing.
	 */
            
	// The power-series converges much faster on positive values
	// and exp(-x) = 1/exp(x).
	bool neg = (inValue < 0);
	if (neg) inValue = -inValue;
            
	fix16_t result = inValue + fix16_one;
	fix16_t term = inValue;

	uint_fast8_t i;        
	for (i = 2; i < 30; i++)
	{
#ifdef FIXMATH_SATURATED_ONLY
		term = fix16_smul(term, fix16_sdiv(inValue, fix16_from_int(i)));
#else
		term = fix16_mul(term, fix16_div(inValue, fix16_from_int(i)));
#endif
		result += term;
                
		if ((term < 500) && ((i > 15) || (term < 20)))
			break;
	}
#ifdef FIXMATH_SATURATED_ONLY
	if (neg) result = fix16_sdiv(fix16_one, result);
#else
	if (neg) result = fix16_div(fix16_one, result);
#endif
            
	#ifndef FIXMATH_NO_CACHE
	_fix16_exp_cache_index[tempIndex] = inValue;
	_fix16_exp_cache_value[tempIndex] = result;
	#endif

	return result;
}


fix16_t fix16_log(fix16_t inValue)
{
	fix16_t guess = fix16_from_int(2);
	fix16_t delta;
	int scaling = 0;
	int count = 0;
	
	if (inValue <= 0)
		return fix16_minimum;
	
	// Bring the value to the most accurate range (1 < x < 100)
	const fix16_t e_to_fourth = 3578144;
	while (inValue > fix16_from_int(100))
	{
#ifdef FIXMATH_SATURATED_ONLY
		inValue = fix16_sdiv(inValue, e_to_fourth);
#else
		inValue = fix16_div(inValue, e_to_fourth);
#endif
		scaling += 4;
	}
	
	while (inValue < fix16_one)
	{
#ifdef FIXMATH_SATURATED_ONLY
		inValue = fix16_smul(inValue, e_to_fourth);
#else
		inValue = fix16_mul(inValue, e_to_fourth);
#endif
		scaling -= 4;
	}
	
	do
	{
		// Solving e(x) = y using Newton's method
		// f(x) = e(x) - y
		// f'(x) = e(x)
		fix16_t e = fix16_exp(guess);
#ifdef FIXMATH_SATURATED_ONLY
		delta = fix16_sdiv(inValue - e, e);
#else
		delta = fix16_div(inValue - e, e);
#endif
		
		// It's unlikely that logarithm is very large, so avoid overshooting.
		if (delta > fix16_from_int(3))
			delta = fix16_from_int(3);
		
		guess += delta;
	} while ((count++ < 10)
		&& ((delta > 1) || (delta < -1)));
	
	return guess + fix16_from_int(scaling);
}



static inline fix16_t fix16_rs(fix16_t x)
{
	#ifdef FIXMATH_NO_ROUNDING
		return (x >> 1);
	#else
		fix16_t y = (x >> 1) + (x & 1);
		return y;
	#endif
}

/**
 * This assumes that the input value is >= 1.
 * 
 * Note that this is only ever called with inValue >= 1 (because it has a wrapper to check. 
 * As such, the result is always less than the input. 
 */
static fix16_t fix16__log2_inner(fix16_t x)
{
	fix16_t result = 0;
	
	while(x >= fix16_from_int(2))
	{
		result++;
		x = fix16_rs(x);
	}

	if(x == 0) return (result << 16);

	uint_fast8_t i;
	for(i = 16; i > 0; i--)
	{
#ifdef FIXMATH_SATURATED_ONLY
		x = fix16_smul(x, x);
#else
		x = fix16_mul(x, x);
#endif
		result <<= 1;
		if(x >= fix16_from_int(2))
		{
			result |= 1;
			x = fix16_rs(x);
		}
	}
	#ifndef FIXMATH_NO_ROUNDING
#ifdef FIXMATH_SATURATED_ONLY
		x = fix16_smul(x, x);
#else
		x = fix16_mul(x, x);
#endif
		if(x >= fix16_from_int(2)) result++;
	#endif
	
	return result;
}



/**
 * calculates the log base 2 of input.
 * Note that negative inputs are invalid! (will return fix16_overflow, since there are no exceptions)
 * 
 * i.e. 2 to the power output = input.
 * It's equivalent to the log or ln functions, except it uses base 2 instead of base 10 or base e.
 * This is useful as binary things like this are easy for binary devices, like modern microprocessros, to calculate.
 * 
 * This can be used as a helper function to calculate powers with non-integer powers and/or bases.
 */
fix16_t fix16_log2(fix16_t x)
{
	// Note that a negative x gives a non-real result.
	// If x == 0, the limit of log2(x)  as x -> 0 = -infinity.
	// log2(-ve) gives a complex result.
	if (x <= 0) return fix16_overflow;

	// If the input is less than one, the result is -log2(1.0 / in)
	if (x < fix16_one)
	{
		// Note that the inverse of this would overflow.
		// This is the exact answer for log2(1.0 / 65536)
		if (x == 1) return fix16_from_int(-16);
#ifdef FIXMATH_SATURATED_ONLY
		fix16_t inverse = fix16_sdiv(fix16_one, x);
#else
		fix16_t inverse = fix16_div(fix16_one, x);
#endif
		return -fix16__log2_inner(inverse);
	}

	// If input >= 1, just proceed as normal.
	// Note that x == fix16_one is a special case, where the answer is 0.
	return fix16__log2_inner(x);
}

/**
 * This is a wrapper for fix16_log2 which implements saturation arithmetic.
 */
fix16_t fix16_slog2(fix16_t x)
{
	fix16_t retval = fix16_log2(x);
	// The only overflow possible is when the input is negative.
	if(retval == fix16_overflow)
		return fix16_minimum;
	return retval;
}
