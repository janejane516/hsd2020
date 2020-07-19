#include "fpga_api.h"
#include <stdio.h>
#include <iostream>
#include <cstring>
#include <cmath>

using namespace std;

#define min(x, y) (((x) < (y)) ? (x) : (y))
float min_act, max_act, min_weight, max_weight;

FPGA::FPGA(off_t data_addr, off_t output_addr, int m_size, int v_size)
{
  m_size_ = m_size;
  v_size_ = v_size;
  data_size_ = (m_size_ + 1) * v_size_; // fpga bram data size

  qvec_ = new char[v_size_];
  qmat_ = new char[m_size_*v_size_];
  qout_ = new short[m_size_];

  output_ = new unsigned int[m_size_]; // use output_ as tempolar output
  data_ = new float[data_size_];

  num_block_call_ = 0;
}

FPGA::~FPGA()
{
  delete[] output_;
  delete[] data_;
  delete[] qvec_;
  delete[] qmat_;
  delete[] qout_;
}

float *FPGA::matrix(void)
{
  return data_;
}

float *FPGA::vector(void)
{
  return data_ + v_size_ * m_size_;
}

void FPGA::reset(void)
{
  num_block_call_ = 0;
}

int FPGA::num_block_call(void)
{
  return num_block_call_;
}

void quantize(float* input, char* quantized, int num_input, char bits_min, char bits_max, char offset, float scale)
{
  for(int i = 0; i < num_input; i++)
  {
    float tmp = ceil(input[i]/scale) + offset;
    if(tmp > (float)bits_max) quantized[i] = bits_max;
    else if(tmp < (float)bits_min) quantized[i] = bits_min;
    else quantized[i] = (char)tmp;
  }
}

void dequantize(short* quantized, float* output, int num_output, char offset, float scale)
{
  for(int i = 0; i < num_output; i++)
  {
    output[i] = (float)(quantized[i]*scale);
  }
}

const float *FPGA::blockMV(Compute* comp)
{
  num_block_call_ += 1;

  // cpu version
  float *vec = this->vector();
  float *mat = this->matrix();
  float *out = reinterpret_cast<float *>(output_);

  if(comp->quantized)
  {
    char act_bits_min = 0;
    char act_bits_max = (1<<(comp->act_bits-1))-1;

    float act_scale = (max_act - min_act) / (act_bits_max - act_bits_min);
    char act_offset = (act_bits_min) - ceil(min_act / act_scale);
    quantize(vec, qvec_, v_size_, act_bits_min, act_bits_max, act_offset, act_scale);

    char weight_bits_min = 0;
    char weight_bits_max = (1<<(comp->weight_bits-1))-1;

    float weight_scale = (max_weight - min_weight) / (weight_bits_max - weight_bits_min);
    char weight_offset = weight_bits_min - ceil(min_weight/weight_scale);
    quantize(mat, qmat_, m_size_*v_size_, weight_bits_min, weight_bits_max, weight_offset, weight_scale);

    for (int i = 0; i < m_size_; ++i)
    {
      qout_[i] = 0;
      for (int j = 0; j < v_size_; ++j)
        qout_[i] += (qvec_[j]-act_offset) * (qmat_[v_size_ * i + j]-weight_offset);
    }

    dequantize(qout_, out, m_size_, 0, act_scale*weight_scale);
  }
  else
  {
    for (int i = 0; i < m_size_; ++i)
    {
      out[i] = 0;
      for (int j = 0; j < v_size_; ++j)
        out[i] += vec[j] * mat[v_size_ * i + j];
    }
  }

  for (int i = 0; i < m_size_; ++i)
    data_[i] = out[i];

  return data_;
}

void FPGA::largeMV(const float *large_mat, const float *input, float *output, int num_input, int num_output, Compute* comp)
{
  min_act = input[0];
  max_act = input[0];
  for(int i=0; i<num_input; i++) {
    if(min_act > input[i])
      min_act = input[i];
    if(max_act < input[i])
      max_act = input[i];
  }

  min_weight = large_mat[0];
  max_weight = large_mat[0];
  for(int i=0; i<num_output; i++) {
    for(int j=0; j<num_input; j++) {
      float tmp = large_mat[i*num_input + j];
      if(min_weight > tmp)
        min_weight = tmp;
      if(max_weight < tmp)
        max_weight = tmp;
    }
  }
   
  float *vec = this->vector();
  float *mat = this->matrix();

  // 0) Initialize output vector
  for (int i = 0; i < num_output; ++i)
    output[i] = 0;

  for (int i = 0; i < num_output; i += m_size_)
  {
    for (int j = 0; j < num_input; j += v_size_)
    {
      // 0) Initialize input vector
      int block_row = min(m_size_, num_output - i);
      int block_col = min(v_size_, num_input - j);

      // 1) Assign a vector
      memcpy(vec, input + j, block_col*sizeof(float));
      memset(vec + block_col, 0, (v_size_ - block_col)*sizeof(float));

      // 2) Assign a matrix
      memset(mat, 0, m_size_*v_size_*sizeof(float));
      for(int k=0; k<block_row; k++) {
        memcpy(mat + k*v_size_, large_mat + (i + k)*num_input + j, block_col*sizeof(float));
      }

      // 3) Call a function `blockMV() to execute MV multiplication
      const float* ret = this->blockMV(comp);

      // 4) Accumulate intermediate results
      for (int row = 0; row < block_row; ++row)
        output[i + row] += ret[row];
    }
  }
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
