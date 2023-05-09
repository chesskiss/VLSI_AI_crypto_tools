#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdio.h>

#include "include/neural_network.h"

// Convert a pixel value from 0-255 to one from 0 to 1
#define PIXEL_SCALE(x) (((uint32_t) (x)<<8) )
//#define PIXEL_SCALE(x) (((float) (x)) / 255.0f)

/**
 * Calculate the softmax vector from the activations. This uses a more
 * numerically stable algorithm that normalises the activations to prevent
 * large exponents.
 */
void neural_network_softmax(fix16_t * activations, int length)
{
    int i;
	int maxIndex=-1;
    fix16_t sum, max;
    fix16_t tmp;

    for (i = 1, max = activations[0]; i < length; i++) {
        tmp = fix16_ssub(activations[i],  max);
        if ((tmp & 0x80000000) ==0) {
        //if (activations[i] > max) {
            max = activations[i];
			maxIndex=i;
        }
    }

    for (i = 0, sum = 0; i < length; i++) {
		if (i == maxIndex){
			activations[i] = 0x00010000;
		}
		else{
			activations[i] = fix16_exp(fix16_ssub(activations[i], max));
		}
		
        //activations[i] = exp(activations[i] - max);
        sum = fix16_sadd(sum, activations[i]);
	//sum += activations[i];
    }

    for (i = 0; i < length; i++) {
        activations[i] = fix16_div(activations[i], sum);
        //activations[i] /= sum;
    }
}

/**
 * Use the weights and bias vector to forward propogate through the neural
 * network and calculate the activations.
 */
void neural_network_hypothesis(uint8_t * image, neural_network_t * network, fix16_t activations[MNIST_LABELS])
{
    int i, j;
    fix16_t tmp;
	fix16_t currentWeight;
	fix16_t currentImage;
	
	for (i=0; i<MNIST_LABELS*MNIST_IMAGE_SIZE; i++){
		
	}


		//for 0 < 10 labels
    for (i = 0; i < MNIST_LABELS; i++) {
        activations[i] = network->b[i];

		//fix16_t ptrA = (void*)0x30008;
		//*ptrA = 0x1111111;
		//fix16_t ptrB = (void*)0x3000C;
		//*ptrB = 0x1111111;
		//fix16_t ptrC = (void*)0x30010;
		//*ptrC = 0x1111111;
		//fix16_t ptrGO = (void*)0x30000;
		//*ptrGO = 0x1111111;

		
		//for 0 < 49 imgsize
		int flagg=0;
        for (j = 0; j < MNIST_IMAGE_SIZE; j++) {
			currentWeight = network->W[i][j];
			currentImage = PIXEL_SCALE(image[j]);
			
			if ((currentImage !=0 ) && (currentWeight !=0)){
				//if (currentImage == 1 ){
				//	printf("1 tmp is %u.  img is: %u,  weight is %u", tmp, currentImage, currentWeight);
				//}


				//if (currentImage == 0x1 ){
				//	printf("hex1 tmp is %u.  img is: %u,  weight is %u\n", tmp, currentImage, currentWeight);
				//}
				//else{
					tmp = fix16_smul(currentWeight, currentImage);
					//if (tmp == currentImage || tmp == currentWeight){
						//printf("tmp is %u.  img is: %u,  weight is %u", tmp, currentImage, currentWeight);
						//printf("i is: %d  j is: %d ",i, j);
					//}
					//int xx = fix16_sadd(activations[i], tmp);
					//if (image[j] == 0x1){
					//	printf("hex1 tmp is %u,  img is: %u,  weight is %u,   xx: %u \n", tmp, currentImage, currentWeight, xx);
				//}
					activations[i] = fix16_sadd(activations[i], tmp);
				//}
				
			}


            //activations[i] += network->W[i][j] * PIXEL_SCALE(image[j]);
        }
    }

    neural_network_softmax(activations, MNIST_LABELS);
}

 