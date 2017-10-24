module dopt.nnet.layers.batchnorm;

import dopt;

Layer batchNorm(Layer input)
{
    auto x = input.output;
    auto xTr = input.trainOutput;

    auto gamma = float32([1, x.shape[1], 1, 1]);
    auto beta = float32([x.shape[1]]);

    auto y = x.batchNormTrain(gamma, beta);
    auto yTr = xTr.batchNormTrain(gamma, beta);

    return new Layer([input], y, yTr, [Parameter(gamma, null, null), Parameter(beta, null, null)]);
}