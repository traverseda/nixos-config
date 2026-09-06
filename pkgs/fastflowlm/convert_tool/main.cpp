// flm-quantize: converts a local HuggingFace safetensors checkpoint into
// FastFlowLM's .q4nx format, using the Q4NX::convert_model() implementation
// that ships (unstripped, exported) inside FastFlowLM's own
// libq4_npu_eXpress.so - it's just never called from the public `flm` CLI.
//
// Usage: flm-quantize <input_hf_model_dir> <output_dir>
//   input_hf_model_dir: a directory with config.json + *.safetensors
//   output_dir: where config.json + model.q4nx get written
//
// Not part of upstream FastFlowLM.
#include "tensor_utils/q4_npu_eXpress.hpp"
#include <filesystem>
#include <iostream>

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <input_hf_model_dir> <output_dir>" << std::endl;
        return 1;
    }

    std::string input_dir = argv[1];
    std::string output_dir = argv[2];

    if (!std::filesystem::exists(input_dir)) {
        std::cerr << "Input directory does not exist: " << input_dir << std::endl;
        return 1;
    }
    std::filesystem::create_directories(output_dir);

    try {
        std::cout << "Loading safetensors from: " << input_dir << std::endl;
        Q4NX q4nx(input_dir);
        std::cout << "Converting to q4nx, writing to: " << output_dir << std::endl;
        q4nx.convert_model(output_dir);
    }
    catch (const std::exception& e) {
        std::cerr << "Conversion failed: " << e.what() << std::endl;
        return 1;
    }

    std::cout << "Done." << std::endl;
    return 0;
}
