#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#define DATASET_SIZE 200
#include "include/neural_network.h"
#include "include/neural_network_weights.h"
#include "include/csr.h"
#include "data/images.h"
#include "data/labels.h"
//#define PRINT_IMAGE

unsigned int max_inf_time_h = 0;
unsigned int max_inf_time_l = 0;


/** * Calculate the accuracy of the predictions of a neural network on a dataset.  */

fix16_t calculate_accuracy(uint8_t images[][MNIST_IMAGE_SIZE], uint8_t labels[], uint32_t dataset_size, neural_network_t * network)
{
    fix16_t activations[MNIST_LABELS], max_activation;
    fix16_t tmp;
    int i, j, correct, predict;
    unsigned int inf_time_l_start, inf_time_h_start, inf_time_l_end, inf_time_h_end, inf_time_l, inf_time_h;

    // Loop through the dataset
    for (i = 0, correct = 0; i < dataset_size; i++) {
        // Calculate the activations for each image using the neural network

	#ifdef PRINT_IMAGE
	for(int k=0; k< MNIST_IMAGE_SIZE; k++){
		if(k%7==0) printf("\n");
		printf("%s", images[i][k]!=0 ? "**" : "  ");
	}
	printf("\nLabel %d\n", labels[i]);
   	#endif

    	//****** Do not remove this/modify code ******
    	inf_time_l_start = csr_read(0xc00);
    	inf_time_h_start = csr_read(0xc80);
    	//****** End of do not remove/modify this code ******
	
        neural_network_hypothesis(images[i], network, activations);
	
    	//****** Do not remove this/modify code ******
    	inf_time_l_end = csr_read(0xc00);
    	inf_time_h_end = csr_read(0xc80);

    	if(inf_time_l_end >= inf_time_l_start){
	    inf_time_l = inf_time_l_end - inf_time_l_start;
	    inf_time_h = inf_time_h_end - inf_time_h_start;
    	}
    	else{
	    inf_time_l = ((unsigned int)0xffffffff - inf_time_l_start) + 1 + inf_time_l_end;
	    inf_time_h = inf_time_h_end - inf_time_h_start-1;
    	}
    	//printf("Total inference time (hex) %08x%08x\n", inf_time_h, inf_time_l);
	if((inf_time_h > max_inf_time_h) || ((inf_time_h == max_inf_time_h)) && (inf_time_l>max_inf_time_l)){
		max_inf_time_h = inf_time_h;
		max_inf_time_l = inf_time_l;
	}
    	//****** End of do not remove/modify this code ******
	
        // Set predict to the index of the greatest activation
        for (j = 0, predict = 0, max_activation = activations[0]; j < MNIST_LABELS; j++) {
	    tmp = fix16_ssub(activations[j], max_activation);
            if ((tmp & 0x80000000) == 0) {
            //if (max_activation < activations[j]) {
                max_activation = activations[j];
                predict = j;
            }
        }

	#ifdef PRINT_IMAGE
	printf("Predicted %d\n", predict);
	#endif

        // Increment the correct count if we predicted the right label
        if (predict == labels[i]) {
            correct++;
        }
    }

    // Return the percentage we predicted correctly as the accuracy
    return fix16_div(((100*correct)<<16) , (dataset_size<<16));
    //return ((float) correct) / ((float) dataset_size);
}

int main(int argc, char *argv[])
{
    fix16_t accuracy;
    //float accuracy;
    int i;
    unsigned int mcycle_l_start, mcycle_h_start;
    unsigned int mcycle_l_end, mcycle_h_end;
    unsigned int total_time_l, total_time_h;

    //****** Do not remove this/modify code ******
    mcycle_l_start = csr_read(0xc00);
    mcycle_h_start = csr_read(0xc80);
    //****** End of do not remove/modify this code ******
    
    accuracy = calculate_accuracy(mnist_images, mnist_labels, DATASET_SIZE, &network_db);

    //****** Do not remove this/modify code ******
    printf("***************** Performance Summary: ******************\n");
    printf("Accuracy[%%]: \t\t\t %d\n", accuracy>>16);
    printf("Start time (hex): \t\t %08x%08x\n", mcycle_h_start, mcycle_l_start);
    mcycle_l_end = csr_read(0xc00);
    mcycle_h_end = csr_read(0xc80);
    printf("End time (hex): \t\t %08x%08x\n", mcycle_h_end, mcycle_l_end);

    if(mcycle_l_end >= mcycle_l_start){
	    total_time_l = mcycle_l_end - mcycle_l_start;
	    total_time_h = mcycle_h_end - mcycle_h_start;
    }
    else{
	    total_time_l = ((unsigned int)0xffffffff - mcycle_l_start) + 1 + mcycle_l_end;
	    total_time_h = mcycle_h_end - mcycle_h_start-1;
    }
    printf("Total time (hex): \t\t %08x%08x\n", total_time_h, total_time_l);
    printf("Worst inference time (hex): \t %08x%08x\n", max_inf_time_h, max_inf_time_l);
    printf("For Throughput calculation divide %d by total time (hex) %08x%08x\n", DATASET_SIZE, total_time_h, total_time_l);
    //****** End of do not remove/modify this code ******

    return 0;
}
