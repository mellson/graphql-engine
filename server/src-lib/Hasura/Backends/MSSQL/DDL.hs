module Hasura.Backends.MSSQL.DDL
  ( buildComputedFieldInfo,
    fetchAndValidateEnumValues,
    buildFunctionInfo,
    updateColumnInEventTrigger,
    parseCollectableType,
    module M,
  )
where

import Data.Aeson
import Hasura.Backends.MSSQL.DDL.BoolExp as M
import Hasura.Backends.MSSQL.DDL.Source as M
import Hasura.Backends.MSSQL.Types.Internal qualified as MT
import Hasura.Base.Error
import Hasura.Prelude
import Hasura.RQL.IR.BoolExp
import Hasura.RQL.Types.Backend
import Hasura.RQL.Types.Column
import Hasura.RQL.Types.Common
import Hasura.RQL.Types.ComputedField
import Hasura.RQL.Types.EventTrigger
import Hasura.RQL.Types.Function
import Hasura.RQL.Types.SchemaCache
import Hasura.RQL.Types.Table
import Hasura.SQL.Backend
import Hasura.SQL.Types
import Hasura.Server.Utils
import Hasura.Session

buildComputedFieldInfo ::
  (MonadError QErr m) =>
  HashSet (TableName 'MSSQL) ->
  TableName 'MSSQL ->
  ComputedFieldName ->
  ComputedFieldDefinition 'MSSQL ->
  RawFunctionInfo 'MSSQL ->
  Maybe Text ->
  m (ComputedFieldInfo 'MSSQL)
buildComputedFieldInfo _ _ _ _ _ _ =
  throw400 NotSupported "Computed fields aren't supported for MSSQL sources"

fetchAndValidateEnumValues ::
  (Monad m) =>
  SourceConfig 'MSSQL ->
  TableName 'MSSQL ->
  Maybe (PrimaryKey 'MSSQL (RawColumnInfo 'MSSQL)) ->
  [RawColumnInfo 'MSSQL] ->
  m (Either QErr EnumValues)
fetchAndValidateEnumValues _ _ _ _ =
  runExceptT $
    throw400 NotSupported "Enum tables are not supported for MSSQL sources"

buildFunctionInfo ::
  (MonadError QErr m) =>
  SourceName ->
  FunctionName 'MSSQL ->
  SystemDefined ->
  FunctionConfig ->
  FunctionPermissionsMap ->
  RawFunctionInfo 'MSSQL ->
  Maybe Text ->
  m (FunctionInfo 'MSSQL, SchemaDependency)
buildFunctionInfo _ _ _ _ _ _ _ =
  throw400 NotSupported "SQL Functions are not supported for MSSQL source"

updateColumnInEventTrigger ::
  TableName 'MSSQL ->
  Column 'MSSQL ->
  Column 'MSSQL ->
  TableName 'MSSQL ->
  EventTriggerConf 'MSSQL ->
  EventTriggerConf 'MSSQL
updateColumnInEventTrigger _ _ _ _ = id

parseCollectableType ::
  (MonadError QErr m) =>
  CollectableType (ColumnType 'MSSQL) ->
  Value ->
  m (PartialSQLExp 'MSSQL)
parseCollectableType collectableType = \case
  String t
    | isSessionVariable t -> pure $ mkTypedSessionVar collectableType $ mkSessionVariable t
    | isReqUserId t -> pure $ mkTypedSessionVar collectableType userIdHeader
  val -> case collectableType of
    CollectableTypeScalar scalarType ->
      PSESQLExp . MT.ValueExpression <$> parseScalarValueColumnType scalarType val
    CollectableTypeArray _ ->
      throw400 NotSupported "Array types are not supported in MSSQL backend"

mkTypedSessionVar ::
  CollectableType (ColumnType 'MSSQL) ->
  SessionVariable ->
  PartialSQLExp 'MSSQL
mkTypedSessionVar columnType =
  PSESessVar (msColumnTypeToScalarType <$> columnType)

msColumnTypeToScalarType :: ColumnType 'MSSQL -> ScalarType 'MSSQL
msColumnTypeToScalarType = \case
  ColumnScalar scalarType -> scalarType
  ColumnEnumReference _ -> MT.TextType
