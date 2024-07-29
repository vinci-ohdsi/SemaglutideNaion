# @author Marc A Suchard
# @date 29 Jul 2024

renv::restore()

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING Strategus ------------
Sys.setenv("_JAVA_OPTIONS"="-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS"=1) # Sets the number of threads to 1 to avoid deadlocks on file system

# ENVIRONMENT SETTINGS FOR ACCESSING AWS to build
# Sys.setenv(DATABASECONNECTOR_JAR_FOLDER="C:/Db")
# DatabaseConnector::downloadJdbcDrivers(dbms = "postgresql") # no longer works

library(Strategus)

connectionDetailsReference <- "Build"
workDatabaseSchema <- 'temp'
cdmDatabaseSchema <- 'cdm'
outputLocation <- "C:/Users/msuch/Documents/SemaglutideNaion/output"
databaseName <- "VA-OMOP"
minCellCount <- 10
cohortTableName <- "sema_naion"

connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  server = keyring::key_get("buildServer"),
  user = keyring::key_get("buildUser"),
  password = keyring::key_get("buildPassword"),
  port = 5432
)

if (!dir.exists(file.path(outputLocation, "results", databaseName))) {
  dir.create(file.path(outputLocation, "results", databaseName), recursive = T)
}

analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = "inst/fullStudyAnalysisSpecification.json"
)

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCoh 
  object = executionSettings,
  fileName = file.path(outputLocation, "results", databaseName, "executionSettings.json")
)




# Note: this environmental variable should be set once for each compute node
# Sys.setenv("INSTANTIATED_MODULES_FOLDER" = file.path(outputLocation, "StrategusInstantiatedModules"))
# ensureAllModulesInstantiated(analysisSpecifications = analysisSpecifications)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)

