
%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <algorithm>

#include "common/log/log.h"
#include "common/lang/string.h"
#include "sql/parser/parse_defs.h"
#include "sql/parser/yacc_sql.hpp"
#include "sql/parser/lex_sql.h"
#include "sql/expr/expression.h"

using namespace std;

string token_name(const char *sql_string, YYLTYPE *llocp)
{
  return string(sql_string + llocp->first_column, llocp->last_column - llocp->first_column + 1);
}

int yyerror(YYLTYPE *llocp, const char *sql_string, ParsedSqlResult *sql_result, yyscan_t scanner, const char *msg)
{
  std::unique_ptr<ParsedSqlNode> error_sql_node = std::make_unique<ParsedSqlNode>(SCF_ERROR);
  error_sql_node->error.error_msg = msg;
  error_sql_node->error.line = llocp->first_line;
  error_sql_node->error.column = llocp->first_column;
  sql_result->add_sql_node(std::move(error_sql_node));
  return 0;
}

ArithmeticExpr *create_arithmetic_expression(ArithmeticExpr::Type type,
                                             Expression *left,
                                             Expression *right,
                                             const char *sql_string,
                                             YYLTYPE *llocp)
{
  ArithmeticExpr *expr = new ArithmeticExpr(type, left, right);
  expr->set_name(token_name(sql_string, llocp));
  return expr;
}

UnboundAggregateExpr *create_aggregate_expression(AggregateType type,
                                           Expression *child,
                                           const char *sql_string,
                                           YYLTYPE *llocp)
{
  UnboundAggregateExpr *expr = new UnboundAggregateExpr(type, child);
  expr->set_name(token_name(sql_string, llocp));
  return expr;
}

%}

%define api.pure full
%define parse.error verbose
/** 启用位置标识 **/
%locations
%lex-param { yyscan_t scanner }
/** 这些定义了在yyparse函数中的参数 **/
%parse-param { const char * sql_string }
%parse-param { ParsedSqlResult * sql_result }
%parse-param { void * scanner }

//标识tokens
%token  SEMICOLON
        BY
        CREATE
        DROP
        GROUP
        TABLE
        TABLES
        VIEW
        INDEX
        UNIQUE
        CALC
        SELECT
        DESC
        SHOW
        SYNC
        INSERT
        DELETE
        UPDATE
        LBRACE
        RBRACE
        COMMA
        TRX_BEGIN
        TRX_COMMIT
        TRX_ROLLBACK
        INT_T
        STRING_T
        FLOAT_T
        DATE_T
        VECTOR_T
        HELP
        EXIT
        DOT //QUOTE
        INTO
        VALUES
        FROM
        INNER_JOIN
        WHERE
        HAVING
        AND
        OR
        SET
        ON
        IN
        NOT_IN
        EXISTS
        NOT_EXISTS
        LOAD
        ORDER
        ASC
        INFILE
        EXPLAIN
        STORAGE
        FORMAT
        AS
        EQ
        LT
        GT
        LE
        GE
        NE
        NOT
        NULL_T
        LIKE
        L2_DISTANCE
        COSINE_DISTANCE
        INNER_PRODUCT
        IS
        COUNT
        MAX
        MIN
        AVG
        SUM
        TEXT_T
        LIMIT
        WITH

/** union 中定义各种数据类型，真实生成的代码也是union类型，所以不能有非POD类型的数据 **/
%union {
  ParsedSqlNode *                            sql_node;
  ConditionSqlNode *                         condition;
  Value *                                    value;
  enum CompOp                                comp;
  RelAttrSqlNode *                           rel_attr;
  RelationSqlNode *                          relation;
  OrderBySqlNode *                           order_by_node;
  std::vector<OrderBySqlNode> *              order_by_list;
  std::vector<AttrInfoSqlNode> *             attr_infos;
  AttrInfoSqlNode *                          attr_info;
  Expression *                               expression;
  std::vector<std::unique_ptr<Expression>> * expression_list;
  std::vector<Value> *                       value_list;
  std::vector<ConditionSqlNode> *            condition_list;
  std::vector<RelAttrSqlNode> *              rel_attr_list;
  std::vector<RelationSqlNode> *             relation_list;
  std::vector<JoinSqlNode> *                 join_list;
  char *                                     string;
  int                                        number;
  float                                      floats;
  std::vector<UpdateInfoNode>*               update_info_list;
  std::vector<std::string>*                  string_list;
}


%token <number> NUMBER
%token <floats> FLOAT
%token <string> ID
%token <string> SSS
%token <string> DATE
%token <string> VECTOR
//非终结符

/** 
 * type 定义了各种解析后的结果输出的是什么类型。类型对应了 union 中的定义的成员变量名称 
 * 左边是上面的 union 中定义的类型，右边是在下面用到的 token，意思就是右边的 token 解析后的结果是左边的类型
 **/
%type <number>              type
%type <condition>           condition
%type <value>               value
%type <number>              number
%type <relation>            relation
%type <comp>                comp_op
%type <rel_attr>            rel_attr
%type <attr_infos>          attr_def_list
%type <attr_info>           attr_def
%type <value_list>          value_list
%type <condition_list>      where
%type <condition_list>      condition_list
%type <condition_list>      having
%type <number>              limit
%type <join_list>           join_list
%type <string>              storage_format
%type <relation_list>       rel_list
%type <expression>          expression
%type <expression_list>     expression_list
%type <expression_list>     group_by
%type <order_by_list>       order_by_list
%type <order_by_list>       order_by
%type <order_by_node>       order_by_item
%type <sql_node>            calc_stmt
%type <sql_node>            select_stmt
%type <sql_node>            insert_stmt
%type <sql_node>            update_stmt
%type <sql_node>            delete_stmt
%type <sql_node>            create_table_stmt
%type <sql_node>            drop_table_stmt
%type <sql_node>            show_tables_stmt
%type <sql_node>            desc_table_stmt
%type <sql_node>            create_view_stmt
%type <sql_node>            create_index_stmt
%type <sql_node>            create_vector_index_stmt
%type <string>              id_or_number
%type <sql_node>            drop_index_stmt
%type <sql_node>            sync_stmt
%type <sql_node>            begin_stmt
%type <sql_node>            commit_stmt
%type <sql_node>            rollback_stmt
// %type <sql_node>            load_data_stmt
%type <sql_node>            explain_stmt
%type <sql_node>            set_variable_stmt
%type <sql_node>            help_stmt
%type <sql_node>            exit_stmt
%type <sql_node>            command_wrapper
%type <update_info_list>    update_list
%type <string_list>         id_list
// commands should be a list but I use a single command instead
%type <sql_node>            commands

%left '+' '-'
%left '*' '/'
%nonassoc UMINUS
%%

commands: command_wrapper opt_semicolon  //commands or sqls. parser starts here.
  {
    std::unique_ptr<ParsedSqlNode> sql_node = std::unique_ptr<ParsedSqlNode>($1);
    sql_result->add_sql_node(std::move(sql_node));
  }
  ;

command_wrapper:
    calc_stmt
  | select_stmt
  | insert_stmt
  | update_stmt
  | delete_stmt
  | create_table_stmt
  | drop_table_stmt
  | show_tables_stmt
  | desc_table_stmt
  | create_view_stmt
  | create_index_stmt
  | create_vector_index_stmt
  | drop_index_stmt
  | sync_stmt
  | begin_stmt
  | commit_stmt
  | rollback_stmt
  // | load_data_stmt
  | explain_stmt
  | set_variable_stmt
  | help_stmt
  | exit_stmt
    ;

exit_stmt:      
    EXIT {
      (void)yynerrs;  // 这么写为了消除yynerrs未使用的告警。如果你有更好的方法欢迎提PR
      $$ = new ParsedSqlNode(SCF_EXIT);
    };

help_stmt:
    HELP {
      $$ = new ParsedSqlNode(SCF_HELP);
    };

sync_stmt:
    SYNC {
      $$ = new ParsedSqlNode(SCF_SYNC);
    }
    ;

begin_stmt:
    TRX_BEGIN  {
      $$ = new ParsedSqlNode(SCF_BEGIN);
    }
    ;

commit_stmt:
    TRX_COMMIT {
      $$ = new ParsedSqlNode(SCF_COMMIT);
    }
    ;

rollback_stmt:
    TRX_ROLLBACK  {
      $$ = new ParsedSqlNode(SCF_ROLLBACK);
    }
    ;

drop_table_stmt:    /*drop table 语句的语法解析树*/
    DROP TABLE ID {
      $$ = new ParsedSqlNode(SCF_DROP_TABLE);
      $$->drop_table.relation_name = $3;
      free($3);
    };

show_tables_stmt:
    SHOW TABLES {
      $$ = new ParsedSqlNode(SCF_SHOW_TABLES);
    }
    ;

desc_table_stmt:
    DESC ID  {
      $$ = new ParsedSqlNode(SCF_DESC_TABLE);
      $$->desc_table.relation_name = $2;
      free($2);
    }
    ;

create_index_stmt:    /*create index 语句的语法解析树*/
    CREATE INDEX ID ON ID LBRACE id_list RBRACE
    {
      $$ = new ParsedSqlNode(SCF_CREATE_INDEX);
      CreateIndexSqlNode &create_index = $$->create_index;
      create_index.index_name = $3;
      create_index.relation_name = $5;
      create_index.attribute_names = *$7;
      create_index.is_unique = false;
      free($3);
      free($5);
      if ($7 != nullptr) {
        // 因为是从右往左解析的，所以需要反转
        std::reverse($$->create_index.attribute_names.begin(), $$->create_index.attribute_names.end());
        delete $7;
      }
    }
    | CREATE UNIQUE INDEX ID ON ID LBRACE id_list RBRACE
    {
      $$ = new ParsedSqlNode(SCF_CREATE_INDEX);
      CreateIndexSqlNode &create_index = $$->create_index;
      create_index.index_name = $4;
      create_index.relation_name = $6;
      create_index.attribute_names = *$8;
      create_index.is_unique = true;
      free($4);
      free($6);
      if ($8 != nullptr) {
        // 因为是从右往左解析的，所以需要反转
        std::reverse($$->create_index.attribute_names.begin(), $$->create_index.attribute_names.end());
        delete $8;
      }
    }
    ;
id_or_number:
    ID
    {
        $$ = new char[strlen($1) + 1];
        strcpy($$, $1);
        $$[strlen($1)] = '\0';
    }
    | NUMBER
    {
        $$ = new char[20];
        sprintf($$, "%d", $1);
    }
    | L2_DISTANCE
    {
        const char* s = "l2_distance";
        $$ = new char[strlen(s) + 1];
        strcpy($$, s);
        $$[strlen(s)] = '\0';
    }
    | INNER_PRODUCT
    {
        const char* s = "inner_product";
        $$ = new char[strlen(s) + 1];
        strcpy($$, s);
        $$[strlen(s)] = '\0';
    }
    | COSINE_DISTANCE
    {
        const char* s = "cossine_distance";
        $$ = new char[strlen(s) + 1];
        strcpy($$, s);
        $$[strlen(s)] = '\0';
    }
    ;

create_vector_index_stmt:
    // 1     2       3     4  5  6   7    8    9    10     11    12 13      14       15    16 17     18        19   20 21    22         23   24 25     26        27
    CREATE VECTOR_T INDEX ID ON ID LBRACE ID RBRACE WITH  LBRACE ID EQ id_or_number COMMA  ID EQ id_or_number COMMA ID EQ id_or_number COMMA ID EQ id_or_number RBRACE
    {
        $$ = new ParsedSqlNode(SCF_CREATE_VECTOR_INDEX);
        CreateVectorIndexSqlNode &create_vector_index = $$->create_vector_index;
        create_vector_index.index_name = $4;
        create_vector_index.relation_name = $6;
        create_vector_index.attribute_names = $8;
        create_vector_index.params[0] = {$12, $14};
        create_vector_index.params[1] = {$16, $18};
        create_vector_index.params[2] = {$20, $22};
        create_vector_index.params[3] = {$24, $26};
        free($4);
        free($6);
        free($8);
        free($12);
        delete[] $14;
        free($16);
        delete[] $18;
        free($20);
        delete[] $22;
        free($24);
        delete[] $26;
    }
    ;

drop_index_stmt:      /*drop index 语句的语法解析树*/
    DROP INDEX ID ON ID
    {
      $$ = new ParsedSqlNode(SCF_DROP_INDEX);
      $$->drop_index.index_name = $3;
      $$->drop_index.relation_name = $5;
      free($3);
      free($5);
    }
    ;
create_table_stmt:    /*create table 语句的语法解析树*/
    CREATE TABLE ID LBRACE attr_def attr_def_list RBRACE storage_format
    {
      $$ = new ParsedSqlNode(SCF_CREATE_TABLE);
      CreateTableSqlNode &create_table = $$->create_table;
      create_table.relation_name = $3;
      free($3);

      std::vector<AttrInfoSqlNode> *src_attrs = $6;

      if (src_attrs != nullptr) {
        create_table.attr_infos.swap(*src_attrs);
        delete src_attrs;
      }
      create_table.attr_infos.emplace_back(*$5);
      std::reverse(create_table.attr_infos.begin(), create_table.attr_infos.end());
      delete $5;
      if ($8 != nullptr) {
        create_table.storage_format = $8;
        free($8);
      }
    }
    // as
    | CREATE TABLE ID AS select_stmt
    {
      $$ = new ParsedSqlNode(SCF_CREATE_TABLE);
      CreateTableSqlNode &create_table = $$->create_table;
      create_table.relation_name = $3;
      free($3);
      create_table.sub_select = $5;
    }
    // as with attributes
    | CREATE TABLE ID LBRACE attr_def attr_def_list RBRACE AS select_stmt
    {
      $$ = new ParsedSqlNode(SCF_CREATE_TABLE);
      CreateTableSqlNode &create_table = $$->create_table;
      create_table.relation_name = $3;
      free($3);

      std::vector<AttrInfoSqlNode> *src_attrs = $6;

      if (src_attrs != nullptr) {
        create_table.attr_infos.swap(*src_attrs);
        delete src_attrs;
      }
      create_table.attr_infos.emplace_back(*$5);
      std::reverse(create_table.attr_infos.begin(), create_table.attr_infos.end());
      delete $5;
      create_table.sub_select = $9;
    }
    | CREATE TABLE ID LBRACE attr_def attr_def_list RBRACE select_stmt
    {
      $$ = new ParsedSqlNode(SCF_CREATE_TABLE);
      CreateTableSqlNode &create_table = $$->create_table;
      create_table.relation_name = $3;
      free($3);

      std::vector<AttrInfoSqlNode> *src_attrs = $6;

      if (src_attrs != nullptr) {
        create_table.attr_infos.swap(*src_attrs);
        delete src_attrs;
      }
      create_table.attr_infos.emplace_back(*$5);
      std::reverse(create_table.attr_infos.begin(), create_table.attr_infos.end());
      delete $5;
      create_table.sub_select = $8;
    }

    ;

create_view_stmt:
    CREATE VIEW ID AS select_stmt
    {
      $$ = new ParsedSqlNode(SCF_CREATE_VIEW);
      CreateViewSqlNode &create_view = $$->create_view;
      create_view.view_name = $3;
      free($3);
      create_view.sub_select = $5;
      // 得到 AS 之后的字符串
      create_view.description = std::string(sql_string + @5.first_column, @5.last_column - @5.first_column + 1);
    }
    | CREATE VIEW ID LBRACE id_list RBRACE AS select_stmt
    {
      $$ = new ParsedSqlNode(SCF_CREATE_VIEW);
      CreateViewSqlNode &create_view = $$->create_view;
      create_view.view_name = $3;
      free($3);

      std::vector<std::string> *src_attrs = $5;
      if (src_attrs != nullptr) {
        create_view.attrs_name.swap(*src_attrs);
        delete src_attrs;
      }
      std::reverse(create_view.attrs_name.begin(), create_view.attrs_name.end());
      
      create_view.sub_select = $8;
      // 得到 AS 之后的字符串
      create_view.description = std::string(sql_string + @8.first_column, @8.last_column - @8.first_column + 1);
    }
    ;

attr_def_list:
    /* empty */
    {
      $$ = nullptr;
    }
    | COMMA attr_def attr_def_list
    {
      if ($3 != nullptr) {
        $$ = $3;
      } else {
        $$ = new std::vector<AttrInfoSqlNode>;
      }
      $$->emplace_back(*$2);
      delete $2;
    }
    ;
    
attr_def:
    ID type LBRACE number RBRACE NOT NULL_T
    {
      $$ = new AttrInfoSqlNode;
      $$->type = (AttrType)$2;
      $$->name = $1;
      $$->arr_len = $4;
      $$->nullable = false;
      free($1);
    }
    | ID type LBRACE number RBRACE NULL_T
    {
          $$ = new AttrInfoSqlNode;
          $$->type = (AttrType)$2;
          $$->name = $1;
          $$->arr_len = $4;
          $$->nullable = true;
          free($1);
    }
    | ID type LBRACE number RBRACE 
    {
      $$ = new AttrInfoSqlNode;
      $$->type = (AttrType)$2;
      $$->name = $1;
      $$->arr_len = $4;
      $$->nullable = true;
      free($1);
    }
    | ID type NOT NULL_T
    {
      $$ = new AttrInfoSqlNode;
      $$->type = (AttrType)$2;
      $$->name = $1;
      $$->arr_len = 1;
      $$->nullable = false;
      free($1);
    }
    | ID type NULL_T
    {
      $$ = new AttrInfoSqlNode;
      $$->type = (AttrType)$2;
      $$->name = $1;
      $$->arr_len = 1;
      $$->nullable = true;
      free($1);
    }
    | ID type
    {
      $$ = new AttrInfoSqlNode;
      $$->type = (AttrType)$2;
      $$->name = $1;
      $$->arr_len = 1;
      $$->nullable = true;
      free($1);
    }
    ;

id_list:
    ID
    {
      $$ = new std::vector<std::string>;
      $$->emplace_back($1);
      free($1);
    }
    | ID COMMA id_list
    {
      if ($3 != nullptr) {
        $$ = $3;
      } else {
        $$ = new std::vector<std::string>;
      }
      $$->emplace_back($1);
      free($1);
    }
    ;

number:
    NUMBER {$$ = $1;}
    ;
type:
    INT_T      { $$ = static_cast<int>(AttrType::INTS); }
    | STRING_T { $$ = static_cast<int>(AttrType::CHARS); }
    | FLOAT_T  { $$ = static_cast<int>(AttrType::FLOATS); }
    | DATE_T   { $$ = static_cast<int>(AttrType::DATES); }
    | VECTOR_T   { $$ = static_cast<int>(AttrType::VECTORS); }
    | TEXT_T     { $$ = static_cast<int>(AttrType::TEXTS); }
    ;
insert_stmt:        /*insert   语句的语法解析树*/
    INSERT INTO ID VALUES LBRACE value value_list RBRACE 
    {
      $$ = new ParsedSqlNode(SCF_INSERT);
      $$->insertion.relation_name = $3;
      if ($7 != nullptr) {
        $$->insertion.values.swap(*$7);
        delete $7;
      }
      $$->insertion.values.emplace_back(*$6);
      std::reverse($$->insertion.values.begin(), $$->insertion.values.end());
      delete $6;
      free($3);
    }
    | INSERT INTO ID LBRACE id_list RBRACE VALUES LBRACE value value_list RBRACE
     {
      $$ = new ParsedSqlNode(SCF_INSERT);
      $$->insertion.relation_name = $3;
      
      // fields list
      if ($5 != nullptr) {
        $$->insertion.attrs_name.swap(*$5);
        delete $5;
      }
      std::reverse($$->insertion.attrs_name.begin(), $$->insertion.attrs_name.end());

      if ($10 != nullptr) {
        $$->insertion.values.swap(*$10);
        delete $10;
      }
      $$->insertion.values.emplace_back(*$9);
      std::reverse($$->insertion.values.begin(), $$->insertion.values.end());
      delete $9;
      free($3);
    }
    ;

value_list:
    /* empty */
    {
      $$ = nullptr;
    }
    | COMMA value value_list  { 
      if ($3 != nullptr) {
        $$ = $3;
      } else {
        $$ = new std::vector<Value>;
      }
      $$->emplace_back(*$2);
      delete $2;
    }
    ;
value:
    NUMBER {
      $$ = new Value((int)$1);
      @$ = @1;
    }
    | 
    '-' NUMBER {
      $$ = new Value(-(int)$2);
      @$ = @2;
    }
    | 
    FLOAT {
      $$ = new Value((float)$1);
      @$ = @1;
    }
    | 
    '-' FLOAT {
      $$ = new Value(-(float)$2);
      @$ = @2;
    }
    | 
    SSS {
      char *tmp = common::substr($1,1,strlen($1)-2);
      $$ = new Value(tmp);
      free(tmp);
      free($1);
    }
    | 
    DATE {
      char *tmp = common::substr($1,1,strlen($1)-2);
      $$ = Value::from_date(tmp);
      if (!$$->is_date_valid()) {
        $$->reset();
      }
      free(tmp);
      free($1);
    }
    |
    VECTOR {
      // 如果以双引号或单引号开头，去掉头尾的引号
      if ($1[0] == '\"' || $1[0] == '\'') {
        char *tmp = common::substr($1,1,strlen($1)-2);
        $$ = Value::from_vector(tmp);
        free(tmp);
      } else {
        $$ = Value::from_vector($1);
      }
      free($1);
    }
    | 
    NULL_T {
      $$ = new Value();
      $$->set_null();
      @$ = @1;
    }
    ;
storage_format:
    /* empty */
    {
      $$ = nullptr;
    }
    | STORAGE FORMAT EQ ID
    {
      $$ = $4;
    }
    ;
    
delete_stmt:    /*  delete 语句的语法解析树*/
    DELETE FROM ID where 
    {
      $$ = new ParsedSqlNode(SCF_DELETE);
      $$->deletion.relation_name = $3;
      if ($4 != nullptr) {
        $$->deletion.conditions.swap(*$4);
        delete $4;
      }
      free($3);
    }
    ;
update_list:
    ID EQ expression COMMA update_list
    {
        $$ = $5;
        $$->emplace_back(std::string($1), $3);
        free($1);
    }
    | ID EQ expression
    {
        $$ = new std::vector<UpdateInfoNode>();
        $$->emplace_back(std::string($1), $3);
        free($1);
    }
    ;
update_stmt:      /*  update 语句的语法解析树*/
    UPDATE ID SET update_list where
    {
      $$ = new ParsedSqlNode(SCF_UPDATE);
      $$->update.relation_name = $2;
      $$->update.update_infos = *$4;
      if ($5 != nullptr) {
        $$->update.conditions.swap(*$5);
        delete $5;
      }
      free($2);
      delete $4;
    }
    ;
select_stmt:        /*  select 语句的语法解析树*/
    SELECT expression_list FROM rel_list join_list where group_by having order_by limit
    {
      $$ = new ParsedSqlNode(SCF_SELECT);
      if ($2 != nullptr) {
        $$->selection.expressions.swap(*$2);
        delete $2;
      }

      // from
      if ($4 != nullptr) {
        $$->selection.relations.swap(*$4);
        std::reverse($$->selection.relations.begin(), $$->selection.relations.end());
        delete $4;
      }

      // join
      if ($5 != nullptr) {
        /* 由于是递归顺序解析的join，需要 reverse */
        std::reverse($5->begin(), $5->end());
        for (auto &join : *$5) {
          $$->selection.relations.push_back(join.relation);
          for (auto &condition : join.conditions) {
            $$->selection.conditions.emplace_back(std::move(condition));
          }
        }
        // delete $5; // TODO(Soulter): free test
      }

      // where
      if ($6 != nullptr) {
        // $$->selection.conditions.swap(*$6);
        for (auto &condition : *$6) {
          $$->selection.conditions.emplace_back(std::move(condition));
        }
        std::reverse($$->selection.conditions.begin(), $$->selection.conditions.end());
        delete $6;
      }

      // group by
      if ($7 != nullptr) {
        $$->selection.group_by.swap(*$7);
        delete $7;
      }

      // having
      if ($8 != nullptr) {
        $$->selection.havings.swap(*$8);
        std::reverse($$->selection.havings.begin(), $$->selection.havings.end());
        delete $8;
      }

      // order by
      if ($9 != nullptr) {
        $$->selection.order_by.swap(*$9);
        std::reverse($$->selection.order_by.begin(), $$->selection.order_by.end());
        delete $9;
      }

      // limit
      $$->selection.limit = $10;
    }
    ;
calc_stmt:
    CALC expression_list
    {
      $$ = new ParsedSqlNode(SCF_CALC);
      $$->calc.expressions.swap(*$2);
      delete $2;
    }
    ;

expression_list:
    expression
    {
      $$ = new std::vector<std::unique_ptr<Expression>>;
      $$->emplace_back($1);
    }
    | expression ID{
      $$ = new std::vector<std::unique_ptr<Expression>>;
      $1->set_alias($2);
      $$->emplace_back($1);
      free($2);
    }
    | expression AS ID{
      $$ = new std::vector<std::unique_ptr<Expression>>;
      $1->set_alias($3);
      $$->emplace_back($1);
      free($3);
    }
    | expression ID COMMA expression_list
    {
      if ($4 != nullptr) {
        $$ = $4;
      } else {
        $$ = new std::vector<std::unique_ptr<Expression>>;
      }
      $1->set_alias($2);
      $$->emplace($$->begin(), $1);
      free($2);
    }
    | expression AS ID COMMA expression_list
    {
      if ($5 != nullptr) {
        $$ = $5;
      } else {
        $$ = new std::vector<std::unique_ptr<Expression>>;
      }
      $1->set_alias($3);
      $$->emplace($$->begin(), $1);
      free($3);
    }
    | expression COMMA expression_list
    {
      if ($3 != nullptr) {
        $$ = $3;
      } else {
        $$ = new std::vector<std::unique_ptr<Expression>>;
      }
      $$->emplace($$->begin(), $1);
    }
    ;
expression:
    COUNT LBRACE expression RBRACE
    {
      $$ = create_aggregate_expression(AggregateType::COUNT, $3, sql_string, &@$);
    }
    | MAX LBRACE expression RBRACE
    {
      $$ = create_aggregate_expression(AggregateType::MAX, $3, sql_string, &@$);
    }
    | MIN LBRACE expression RBRACE
    {
      $$ = create_aggregate_expression(AggregateType::MIN, $3, sql_string, &@$);
    }
    | AVG LBRACE expression RBRACE
    {
      $$ = create_aggregate_expression(AggregateType::AVG, $3, sql_string, &@$);
    }
    | SUM LBRACE expression RBRACE
    {
      $$ = create_aggregate_expression(AggregateType::SUM, $3, sql_string, &@$);
    }
    | expression '+' expression {
      $$ = create_arithmetic_expression(ArithmeticExpr::Type::ADD, $1, $3, sql_string, &@$);
    }
    | expression '-' expression {
      $$ = create_arithmetic_expression(ArithmeticExpr::Type::SUB, $1, $3, sql_string, &@$);
    }
    | expression '*' expression {
      $$ = create_arithmetic_expression(ArithmeticExpr::Type::MUL, $1, $3, sql_string, &@$);
    }
    | expression '/' expression {
      $$ = create_arithmetic_expression(ArithmeticExpr::Type::DIV, $1, $3, sql_string, &@$);
    }
    | LBRACE select_stmt RBRACE {
      $$ = new SubqueryExpr($2);
      $$->set_name(token_name(sql_string, &@$));
    }
    | LBRACE expression RBRACE {
      $$ = $2;
      $$->set_name(token_name(sql_string, &@$));
    }
    | '-' expression %prec UMINUS {
      $$ = create_arithmetic_expression(ArithmeticExpr::Type::NEGATIVE, nullptr, $2, sql_string, &@$);
    }
    | value {
      $$ = new ValueExpr(*$1);
      $$->set_name(token_name(sql_string, &@$));
      delete $1;
    }
    | LBRACE value value_list RBRACE  {
      std::vector<Value> *values = $3;
      values->emplace_back(*$2);
      $$ = new ValueListExpr(*values);
      $$->set_name(token_name(sql_string, &@$));
    }
    | rel_attr {
      RelAttrSqlNode *node = $1;
      $$ = new UnboundFieldExpr(node->relation_name, node->attribute_name);
      $$->set_name(token_name(sql_string, &@$));
      delete $1;
    }
    | '*' {
      $$ = new StarExpr();
    }
    | L2_DISTANCE LBRACE expression COMMA expression RBRACE {
      $$ = new VectorDistanceExpr(VectorDistanceExpr::Type::L2_DISTANCE, $3, $5);
      $$->set_name(token_name(sql_string, &@$));
    }
    | COSINE_DISTANCE LBRACE expression COMMA expression RBRACE {
      $$ = new VectorDistanceExpr(VectorDistanceExpr::Type::COSINE_DISTANCE, $3, $5);
      $$->set_name(token_name(sql_string, &@$));
    }
    | INNER_PRODUCT LBRACE expression COMMA expression RBRACE {
      $$ = new VectorDistanceExpr(VectorDistanceExpr::Type::INNER_PRODUCT, $3, $5);
      $$->set_name(token_name(sql_string, &@$));
    }
    ;

rel_attr:
    ID {
      $$ = new RelAttrSqlNode;
      $$->attribute_name = $1;
      free($1);
    }
    | ID DOT ID {
      $$ = new RelAttrSqlNode;
      $$->relation_name  = $1;
      $$->attribute_name = $3;
      free($1);
      free($3);
    }
    | ID DOT '*' {
      $$ = new RelAttrSqlNode;
      $$->relation_name  = $1;
      $$->attribute_name = "*";
      free($1);
    }
    ;

relation:
    ID {
      $$ = new RelationSqlNode;
      $$->name = $1;
      free($1);
    }
    | ID AS ID {
      $$ = new RelationSqlNode;
      $$->name = $1;
      $$->alias = $3;
      free($1);
      free($3);
    }
    | ID ID {
      $$ = new RelationSqlNode;
      $$->name = $1;
      $$->alias = $2;
      free($1);
      free($2);
    }
    ;

rel_list:
    relation {
      // $$ = new std::vector<std::string>();
      // $$->push_back($1);
      // free($1);
      $$ = new std::vector<RelationSqlNode>;
      $$->emplace_back(*$1);
      // free($1);
      delete $1;
    }
    | relation COMMA rel_list {
      if ($3 != nullptr) {
        $$ = $3;
      } else {
        $$ = new std::vector<RelationSqlNode>;
      }
      $$->emplace_back(*$1);
      // free($1);
      delete $1;
    }
    ;

join_list:
    /* empty */
    {
      $$ = nullptr;
    }
    | INNER_JOIN relation ON condition_list join_list {
      if ($5 != nullptr) {
        $$ = $5;
      } else {
        $$ = new std::vector<JoinSqlNode>;
      }

      JoinSqlNode join1;
      join1.relation = *$2;
      delete $2;
      // reverse
      std::reverse($4->begin(), $4->end());
      for (auto &condition : *$4) {
        join1.conditions.emplace_back(std::move(condition));
      }
      $$->emplace_back(std::move(join1));
    }
    ;

where:
    /* empty */
    {
      $$ = nullptr;
    }
    | WHERE condition_list {
      $$ = $2;  
    }
    ;
condition_list:
    /* empty */
    {
      $$ = nullptr;
    }
    | condition {
      $$ = new std::vector<ConditionSqlNode>;
      $1->conjunction_type = 0;
      $$->push_back(std::move(*$1));
      delete $1;
    }
    | condition AND condition_list {
      $$ = $3;
      $1->conjunction_type = 1;
      $$->push_back(std::move(*$1));
      delete $1;
    }
    | condition OR condition_list {
      $$ = $3;
      $1->conjunction_type = 2;
      $$->push_back(std::move(*$1));
      delete $1;
    }
    ;
condition:
    expression comp_op expression
    {
      $$ = new ConditionSqlNode;
      $$->left_expr = std::unique_ptr<Expression>($1);
      $$->right_expr = std::unique_ptr<Expression>($3);
      $$->comp_op = $2;
    }
    // 懒得之后再判断左 expression 是否为空了，直接在这里加上 EXISTS 吧。
    | EXISTS expression
    {
      $$ = new ConditionSqlNode;
      $$->comp_op = CompOp::EXISTS;
      // left_expr: SpecialPlaceholderExpr
      $$->left_expr = std::make_unique<SpecialPlaceholderExpr>();
      $$->right_expr = std::unique_ptr<Expression>($2);
    }
    | NOT_EXISTS expression
    {
      $$ = new ConditionSqlNode;
      $$->comp_op = CompOp::NOT_EXISTS;
      $$->left_expr = std::make_unique<SpecialPlaceholderExpr>();
      $$->right_expr = std::unique_ptr<Expression>($2);
    }
    ;

comp_op:
      EQ { $$ = CompOp::EQUAL_TO; }
    | LT { $$ = CompOp::LESS_THAN; }
    | GT { $$ = CompOp::GREAT_THAN; }
    | LE { $$ = CompOp::LESS_EQUAL; }
    | GE { $$ = CompOp::GREAT_EQUAL; }
    | NE { $$ = CompOp::NOT_EQUAL; }
    | LIKE { $$ = CompOp::LIKE; }
    | NOT LIKE { $$ = CompOp::NOT_LIKE; }
    | IS { $$ = CompOp::IS; }
    | IS NOT { $$ = CompOp::NOT_IS; }
    | IN { $$ = CompOp::IN; }
    | NOT_IN { $$ = CompOp::NOT_IN; }
    | EXISTS { $$ = CompOp::EXISTS; }
    | NOT_EXISTS { $$ = CompOp::NOT_EXISTS; }
    ;

group_by:
    /* empty */
    {
      $$ = nullptr;
    }
    | GROUP BY expression_list
    {
      $$ = new std::vector<std::unique_ptr<Expression>>;
      $$->swap(*$3);
      delete $3;
    }
    ;

having:
    /* empty */
    {
      $$ = nullptr;
    }
    | HAVING condition_list {
      $$ = $2;
    }
    ;

order_by:
    /* empty */
    {
      $$ = nullptr;
    }
    | ORDER BY order_by_list
    {
      $$ = new std::vector<OrderBySqlNode>;
      $$->swap(*$3);
      delete $3;
    }
    ;

order_by_list:
    order_by_item
    {
      $$ = new std::vector<OrderBySqlNode>;
      $$->push_back(std::move(*$1));
      delete $1;
    }
    | order_by_item COMMA order_by_list
    {
      $$ = $3;
      $$->push_back(std::move(*$1));
      delete $1;
    }
    ;

order_by_item:
    expression
    {
      $$ = new OrderBySqlNode;
      $$->expression = std::unique_ptr<Expression>($1);
      $$->is_desc = false;
    }
    | expression ASC
    {
      $$ = new OrderBySqlNode;
      $$->expression = std::unique_ptr<Expression>($1);
      $$->is_desc = false;
    }
    | expression DESC
    {
      $$ = new OrderBySqlNode;
      $$->expression = std::unique_ptr<Expression>($1);
      $$->is_desc = true;
    }
    ;

limit:
    /* empty */
    {
      $$ = -1;
    }
    | LIMIT NUMBER
    {
      $$ = $2;
    }
    ;

/*
load_data_stmt:
    LOAD DATA INFILE SSS INTO TABLE ID 
    {
      char *tmp_file_name = common::substr($4, 1, strlen($4) - 2);
      
      $$ = new ParsedSqlNode(SCF_LOAD_DATA);
      $$->load_data.relation_name = $7;
      $$->load_data.file_name = tmp_file_name;
      free($7);
      free(tmp_file_name);
    }
    ;
*/

explain_stmt:
    EXPLAIN command_wrapper
    {
      $$ = new ParsedSqlNode(SCF_EXPLAIN);
      $$->explain.sql_node = std::unique_ptr<ParsedSqlNode>($2);
    }
    ;

set_variable_stmt:
    SET ID EQ value
    {
      $$ = new ParsedSqlNode(SCF_SET_VARIABLE);
      $$->set_variable.name  = $2;
      $$->set_variable.value = *$4;
      free($2);
      delete $4;
    }
    | SET ID ID
    {
        $$ = new ParsedSqlNode(SCF_SET_VARIABLE);
        $$->set_variable.name  = $2;
        $$->set_variable.value = Value($3, strlen($3));
        free($2);
        free($3);
    }
    ;

opt_semicolon: /*empty*/
    | SEMICOLON
    ;
%%
//_____________________________________________________________________
extern void scan_string(const char *str, yyscan_t scanner);

int sql_parse(const char *s, ParsedSqlResult *sql_result) {
  yyscan_t scanner;
  yylex_init(&scanner);
  scan_string(s, scanner);
  int result = yyparse(s, sql_result, scanner);
  yylex_destroy(scanner);
  return result;
}