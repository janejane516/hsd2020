#include "fpga_api.h"
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <cstring>
#include <cmath>

#define min(x, y) (((x) < (y)) ? (x) : (y))

FPGA::FPGA(off_t data_addr, off_t output_addr, int m_size, int v_size)
{
  m_size_ = m_size;
  v_size_ = v_size;
  data_size_ = (m_size_ + 1) * v_size_ * sizeof(int); // fpga bram data size

  fd_ = open("/dev/mem", O_RDWR);
  qdata_ = static_cast<int *>(mmap(NULL, data_size_, PROT_READ | PROT_WRITE, MAP_SHARED, fd_, data_addr));
  output_ = static_cast<unsigned int *>(mmap(NULL, sizeof(unsigned int), PROT_READ | PROT_WRITE, MAP_SHARED, fd_, output_addr));

  num_block_call_ = 0;
}

FPGA::~FPGA()
{
  munmap(qdata_, data_size_);
  munmap(output_, sizeof(unsigned int));
  close(fd_);
}

int *FPGA::qmatrix(void)
{
  return qdata_;
}

int *FPGA::qvector(void)
{
  return qdata_ + v_size_ * m_size_;
}

void FPGA::reset(void)
{
  num_block_call_ = 0;
}

int FPGA::num_block_call(void)
{
  return num_block_call_;
}

void quantize(const float* input, int* quantized, int num_input, int bits_min, int bits_max, int offset, float scale)
{
  for(int i = 0; i < num_input; i++)
  {
    float tmp = ceil(input[i]/scale) + offset;
    if(tmp > (float)bits_max) quantized[i] = bits_max;
    else if(tmp < (float)bits_min) quantized[i] = bits_min;
    else quantized[i] = (int)tmp;
    quantized[i] -= offset;
  }
}

void dequantize(int* quantized, float* output, int num_output, int offset, float scale)
{
  for(int i = 0; i < num_output; i++)
  {
    output[i] = (float)(quantized[i]*scale);
  }
}

const int *__attribute__((optimize("O0"))) FPGA::qblockMV(Compute* comp)
{
  num_block_call_ += 1;

  // fpga version
  *output_ = 0x5555;
  while (*output_ == 0x5555)
    ;

  return qdata_;
}

void FPGA::largeMV(const float *large_mat, const float *input, float *output, int num_input, int num_output, Compute* comp)
{
  int *vec = this->qvector();
  int *mat = this->qmatrix();

  int *qlarge_mat = new int[num_input*num_output];
  int *qinput = new int[num_input];
  int *qoutput = new int[num_output];

  // quantize
  float min_act = input[0];
  float max_act = input[0];
  for(int i=0; i<num_input; i++) {
    if(min_act > input[i])
      min_act = input[i];
    if(max_act < input[i])
      max_act = input[i];
  }

  int act_bits_min = 0;
  int act_bits_max = (1<<(comp->act_bits-1))-1;

  float act_scale = (max_act - min_act) / (act_bits_max - act_bits_min);
  int act_offset = act_bits_min - ceil(min_act/act_scale);
  quantize(input, qinput, num_input, act_bits_min, act_bits_max, act_offset, act_scale);

  float min_weight = large_mat[0];
  float max_weight = large_mat[0];
  for(int i=0; i<num_output; i++) {
    for(int j=0; j<num_input; j++) {
      float tmp = large_mat[i*num_input + j];
      if(min_weight > tmp)
        min_weight = tmp;
      if(max_weight < tmp)
        max_weight = tmp;
    }
  }
    
  int weight_bits_min = 0;
  int weight_bits_max = (1<<(comp->weight_bits-1))-1;

  float weight_scale = (max_weight - min_weight) / (weight_bits_max - weight_bits_min);
  int weight_offset = weight_bits_min - ceil(min_weight/weight_scale);
  quantize(large_mat, qlarge_mat, num_input*num_output, weight_bits_min, weight_bits_max, weight_offset, weight_scale);

  // 0) Initialize output vector
  for (int i = 0; i < num_output; ++i)
    qoutput[i] = 0;

  for (int i = 0; i < num_output; i += m_size_)
  {
    for (int j = 0; j < num_input; j += v_size_)
    {
      // 0) Initialize input vector
      int block_row = min(m_size_, num_output - i);
      int block_col = min(v_size_, num_input - j);
      //memset(vec, 0, sizeof(int)*v_size_);
      //memset(mat, 0, sizeof(int)*m_size_*v_size_);

      // 1) Assign a vector
      memcpy(vec, qinput + j, block_col * sizeof(int));
      memset(vec + block_col, 0, (v_size_ - block_col) * sizeof(int));

      // 2) Assign a matrix
      memset(mat, 0, m_size_ * v_size_ * sizeof(int));
      for(int k=0; k<block_row; k++) {
        memcpy(mat + k*v_size_, qlarge_mat + (i + k)*num_input + j, block_col*sizeof(int));
      }

      // 3) Call a function `qblockMV() to execute MV multiplication
      const int* ret = this->qblockMV(comp);

      // 4) Accumulate intermediate results
      for(int row = 0; row < block_row; ++row)
        qoutput[i + row] += ret[row];
    }
  }

  dequantize(qoutput, output, num_output, 0, act_scale*weight_scale);
}

void FPGA::convLowering(const std::vector<std::vector<std::vector<std::vector<float>>>> &cnn_weights,
                        std::vector<std::vector<float>> &new_weights,
                        const std::vector<std::vector<std::vector<float>>> &inputs,
                        std::vector<std::vector<float>> &new_inputs)
{
  /*
   * Arguments:
   *
   * conv_weights: [conv_channel, input_channel, conv_height, conv_width]
   * new_weights: [?, ?]
   * inputs: [input_channel, input_height, input_width]
   * new_inputs: [?, ?]
   *
   */

  int conv_channel = cnn_weights.size();
  int input_channel = cnn_weights[0].size();
  int conv_height = cnn_weights[0][0].size();
  int conv_width = cnn_weights[0][0][0].size();
  //int input_channel = inputs.size();
  int input_height = inputs[0].size();
  int input_width = inputs[0][0].size();

  for(int i=0; i<conv_channel; i++)
    for(int j=0; j<input_channel; j++)
      for(int k=0; k<conv_height; k++)
         for(int l=0; l<conv_width; l++)
           new_weights[i][j*conv_height*conv_width + k*conv_width + l] = cnn_weights[i][j][k][l];
  
  int out_height = input_height - conv_height + 1;
  int out_width = input_width - conv_width + 1;
  for(int i=0; i<input_channel; i++)
    for(int j=0; j<conv_height; j++)
      for(int k=0; k<conv_width; k++)
        for(int l=0; l<out_height; l++)
          for(int m=0; m<out_width; m++)
            new_inputs[i*conv_height*conv_width + j*conv_width + k][l*out_width + m] = inputs[i][j + l][k + m];
}
