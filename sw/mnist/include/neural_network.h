#ifndef NEURAL_NETWORK_H_
#define NEURAL_NETWORK_H_

#include "fix16.h"
#define MNIST_IMAGE_SIZE 7*7
#define MNIST_LABELS 10

typedef struct neural_network_t_ {
    fix16_t b[MNIST_LABELS];
    fix16_t W[MNIST_LABELS][MNIST_IMAGE_SIZE];
} neural_network_t;

void neural_network_hypothesis(uint8_t * image, neural_network_t * network, fix16_t activations[MNIST_LABELS]);


#endif
