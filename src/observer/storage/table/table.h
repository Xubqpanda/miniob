/* Copyright (c) 2021 Xie Meiyi(xiemeiyi@hust.edu.cn) and OceanBase and/or its affiliates. All rights reserved.
miniob is licensed under Mulan PSL v2.
You can use this software according to the terms and conditions of the Mulan PSL v2.
You may obtain a copy of Mulan PSL v2 at:
         http://license.coscl.org.cn/MulanPSL2
THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
See the Mulan PSL v2 for more details. */

//
// Created by Meiyi & Wangyunlai on 2021/5/12.
//

#pragma once

#include "storage/table/vector_data_manager.h"
#include "storage/table/table_meta.h"
#include "common/types.h"
#include "common/lang/span.h"
#include "common/lang/functional.h"
#include "storage/index/vector_index.h"

struct RID;
class Record;
class DiskBufferPool;
class RecordFileHandler;
class RecordFileScanner;
class ChunkFileScanner;
class ConditionFilter;
class DefaultConditionFilter;
class Index;
class VectorIndex;
class IndexScanner;
class RecordDeleter;
class Trx;
class Db;

/**
 * @brief 表
 *
 */
class Table
{
public:
  Table() = default;
  ~Table();

  /**
   * 创建一个表
   * @param path 元数据保存的文件(完整路径)
   * @param name 表名
   * @param base_dir 表数据存放的路径
   * @param attribute_count 字段个数
   * @param attributes 字段
   */
  RC create(Db *db, int32_t table_id, const char *path, const char *name, const char *base_dir,
      span<const AttrInfoSqlNode> attributes, StorageFormat storage_format);

  RC drop(Db *db, const char *table_name, const char *base_dir);

  /**
   * 打开一个表
   * @param meta_file 保存表元数据的文件完整路径
   * @param base_dir 表所在的文件夹，表记录数据文件、索引数据文件存放位置
   */
  RC open(Db *db, const char *meta_file, const char *base_dir);

  /**
   * @brief 根据给定的字段生成一个记录/行
   * @details 通常是由用户传过来的字段，按照schema信息组装成一个record。
   * @param value_num 字段的个数
   * @param values    每个字段的值
   * @param record    生成的记录数据
   */
  RC make_record(int value_num, const Value *values, Record &record);

  /**
   * @brief 在当前的表中插入一条记录
   * @details 在表文件和索引中插入关联数据。这里只管在表中插入数据，不关心事务相关操作。
   * @param record[in/out] 传入的数据包含具体的数据，插入成功会通过此字段返回RID
   */
  RC insert_record(Record &record);
  RC delete_record(const Record &record);

  RC delete_record(const RID &rid);
  RC get_record(const RID &rid, Record &record);

  RC update_index(const Record &old_record, const Record &new_record, const std::vector<FieldMeta> &affectedFields);

  RC recover_insert_record(Record &record);

  // TODO refactor
  RC create_index(Trx *trx, const std::vector<const FieldMeta *> &field_metas, const char *index_name, bool is_unique);

  RC create_vector_index(Trx *trx, const FieldMeta *field_meta, const std::string &vector_index_name,
      DistanceType distance_type, size_t lists, size_t probes);

  RC get_record_scanner(RecordFileScanner &scanner, Trx *trx, ReadWriteMode mode);

  RC get_chunk_scanner(ChunkFileScanner &scanner, Trx *trx, ReadWriteMode mode);

  RecordFileHandler *record_handler() const { return record_handler_; }

  /**
   * @brief 可以在页面锁保护的情况下访问记录
   * @details 当前是在事务中访问记录，为了提供一个“原子性”的访问模式
   * @param rid
   * @param visitor
   * @return RC
   */
  RC visit_record(const RID &rid, function<RC(Record &)> visitor);

public:
  int32_t     table_id() const { return table_meta_.table_id(); }
  const char *name() const;

  Db *db() const { return db_; }

  const TableMeta &table_meta() const;

  RC sync();

private:
  RC insert_entry_of_indexes(const char *record, const RID &rid);
  RC delete_entry_of_indexes(const char *record, const RID &rid, bool error_on_not_exists);
  RC set_value_to_record(char *record_data, const Value &value, const FieldMeta *field);

private:
  RC init_record_handler(const char *base_dir);

public:
  Index *find_index(const char *index_name) const;
  Index *find_index_by_fields(const std::vector<const char *> &field_names) const;

  VectorIndex *find_vector_index(const char *index_name) const;
  VectorIndex *find_vector_index_by_fields(const char *field_names) const;

  std::string text_data_file() const;
  std::string vector_data_file() const;

  bool is_outer_table() const { return is_outer_table_; }
  void set_is_outer_table(bool is_outer_table) { is_outer_table_ = is_outer_table; }
  bool is_view() const { return view_; }

public:
  RC load_text(TextData *data) const;
  RC dump_text(TextData *data) const;

  RC load_vector(VectorData *data) const;
  RC dump_vector(VectorData *data) const;
  RC update_vector(const VectorData *old_vector_data, const VectorData *new_vector_data) const;

private:
protected:
  void set_table_meta(const TableMeta &table_meta) { table_meta_ = table_meta; }
  void set_view(bool view) { view_ = view; }

protected:
  Db                *db_ = nullptr;
  string             base_dir_;
  TableMeta          table_meta_;
  DiskBufferPool    *data_buffer_pool_ = nullptr;  /// 数据文件关联的buffer pool
  RecordFileHandler *record_handler_   = nullptr;  /// 记录操作
  vector<Index *>    indexes_;
  std::vector<VectorIndex *> vector_indexes_;

  std::unique_ptr<VectorDataManager> vector_data_manager_;

  bool is_outer_table_ = false; // 子查询用。判断是否是外层查询的表

  bool view_ = false;
};