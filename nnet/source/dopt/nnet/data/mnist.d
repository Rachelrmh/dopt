module dopt.nnet.data.mnist;

import std.algorithm;
import std.array;
import std.file;
import std.range;
import std.typecons;

import dopt.nnet.data;

auto loadMNIST(string path, bool validation = false)
{
    T[][] loadFeatures(T)(string filename)
    {
        const size_t numFeatures = 28 * 28;

        //Load the data from disk
        ubyte[] raw = cast(ubyte[])read(filename);

        //Skip over the header
        raw = raw[16 .. $];

        //Get the number of instances in this file
        size_t numInstances = raw.length / numFeatures;

        //Allocate space to store the references to each instance
        T[][] result = new T[][numInstances];

        //Convert the ubytes to floats
        T[] features = raw.map!(x => cast(T)x).array();

        //Iterate over each instance and set the references to the correct slice
        for(size_t i = 0; i < numInstances; i++)
        {
            result[i] = features[i * numFeatures .. (i + 1) * numFeatures];
            result[i][] /= 128.0f;
            result[i][] -= 1.0f;
        }

        return result;
    }

    T[][] loadLabels(T)(string filename)
    {
        const size_t numLabels = 10;

        //Load the data from disk
        ubyte[] raw = cast(ubyte[])read(filename);

        //Skip over the header
        raw = raw[8 .. $];

        //Get the number of instances in this file
        size_t numInstances = raw.length;

        //Allocate space to store the references to each instance
        T[][] result = new T[][numInstances];
        T[] labels = new T[numInstances * numLabels];
        labels[] = 0.0;

        //Create the one-hot encoding array and set up references to the appropriate slices for each instance
        for(size_t i = 0; i < numInstances; i++)
        {
            result[i] = labels[i * numLabels .. (i + 1) * numLabels];
            result[i][raw[i]] = 1.0;
        }

        return result;
    }

	auto trainFeatures = loadFeatures!float(path ~ "/train-images-idx3-ubyte");
	auto trainLabels = loadLabels!float(path ~ "/train-labels-idx1-ubyte");
	auto testFeatures = loadFeatures!float(path ~ "/t10k-images-idx3-ubyte");
	auto testLabels = loadLabels!float(path ~ "/t10k-labels-idx1-ubyte");

    if(validation)
    {
        testFeatures = trainFeatures[$ - 10_000 .. $];
        testLabels = trainLabels[$ - 10_000 .. $];
        trainFeatures = trainFeatures[0 .. $ - 10_000];
        trainLabels = trainLabels[0 .. $ - 10_000];
    }

	BatchIterator trainData = new SupervisedBatchIterator(trainFeatures, trainLabels, [[1, 28, 28], [10]], true);
    BatchIterator testData = new SupervisedBatchIterator(testFeatures, testLabels, [[1, 28, 28], [10]], false);

    import std.typecons;

    return tuple!("train", "test")(trainData, testData);
}