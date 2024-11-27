/* Copyright (c) 2021 OceanBase and/or its affiliates. All rights reserved.
miniob is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details. */

//
// Created by wangyunlai on 2021/6/11.
//

#include "common/defs.h"
#include <string.h>
#include <math.h>

#include "common/lang/algorithm.h"

namespace common {

int compare_int(void *arg1, void *arg2)
{
  int v1 = *(int *)arg1;
  int v2 = *(int *)arg2;
  if (v1 > v2) {
    return 1;
  } else if (v1 < v2) {
    return -1;
  } else {
    return 0;
  }
}

int compare_float(void *arg1, void *arg2)
{
  float v1  = *(float *)arg1;
  float v2  = *(float *)arg2;
  float cmp = v1 - v2;
  if (cmp > EPSILON) {
    return 1;
  }
  if (cmp < -EPSILON) {
    return -1;
  }
  return 0;
}

int compare_string(const void *arg1, int arg1_max_length, const void *arg2, int arg2_max_length)
{
  const char *s1     = (const char *)arg1;
  const char *s2     = (const char *)arg2;
  int         maxlen = min(arg1_max_length, arg2_max_length);
  int         result = strncmp(s1, s2, maxlen);
  if (0 != result) {
    return result < 0 ? -1 : 1;
  }

  if (arg1_max_length > maxlen) {
    return 1;
  }

  if (arg2_max_length > maxlen) {
    return -1;
  }
  return 0;
}


float db_str_to_float(const char *str) {
    float this_value = 0;
    bool entering_dot = false;
    int dot_index = 1;
    for (size_t i = 0; i < strlen(str); i++) {
      if (str[i] >= 48 && str[i] <= 57) {
        if (!entering_dot) {
          this_value = this_value * 10 + str[i] - 48;
        } else {
          this_value += (str[i] - 48) * pow(0.1, dot_index++);
        }
      } else {
        if (str[i] == '.' && !entering_dot) {
          entering_dot = true;
        } else break;
      }
    }
    return this_value;
}


}  // namespace common