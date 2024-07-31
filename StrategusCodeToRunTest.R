# -------------------------------------------------------
#                     PLEASE READ
# -------------------------------------------------------
#
# You must call "renv::restore()" and follow the prompts
# to install all of the necessary R libraries to run this
# project. This is a one-time operation that you must do
# before running any code.
#
# -------------------------------------------------------
 
renv::restore()
 
##=========== START OF INPUTS ==========
workDatabaseSchema <- "scratch_asena5"
cdmDatabaseSchema <- "cdm_iqvia_pharmetrics_plus_v2909"
databaseName <- "Pharmetrics" # Only used as a folder name for results from the study
outputLocation <- 'D:/git/ohdsi-studies/SemaglutideNaion'
minCellCount <- 5
cohortTableName <- "sema_naion"
 
# Create the connection details for your CDM
# More details on how to do this are found here:
# https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html
connectionDetails = DatabaseConnector::createConnectionDetails(
  dbms = "redshift",
  connectionString = keyring::key_get("redShiftConnectionStringOhdaPharmetrics", keyring = "ohda"),
  user = keyring::key_get("redShiftUserName", keyring = "ohda"),
  password = keyring::key_get("redShiftPassword", keyring = "ohda")
)
 
##=========== END OF INPUTS ==========
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = "inst/fullStudyAnalysisSpecification.json"
)
 
# UNCOMMENT TO RUN COHORT DIAGNOSTICS
# analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
#   fileName = "inst/cohortDiagnosticsAnalysisSpecification.json"
# )
 
executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, "results", databaseName, "strategusWork"),
  resultsFolder = file.path(outputLocation, "results", databaseName, "strategusOutput"),
  minCellCount = minCellCount
)
 
if (!dir.exists(file.path(outputLocation, "results", databaseName))) {
  dir.create(file.path(outputLocation, "results", databaseName), recursive = T)
}
ParallelLogger::saveSettingsToJson(
  object = executionSettings,
  fileName = file.path(outputLocation, "results", databaseName, "executionSettings.json")
)
 
## VA SPECIFIC CODE START ---------
library(Strategus)
 
# Change the implementation of the CG Module:
cgModule <- CohortGeneratorModule$new()
unlockBinding("execute", cgModule)
cgModule$execute <- function(connectionDetails, analysisSpecifications, executionSettings) {
  super$execute(connectionDetails, analysisSpecifications, executionSettings)
  checkmate::assertClass(executionSettings, "CdmExecutionSettings")
 
  jobContext <- private$jobContext
  cohortDefinitionSet <- super$.createCohortDefinitionSetFromJobContext()
  if (!is.null(jobContext$settings$refactor) && jobContext$settings$refactor) {
    for (i in 1:nrow(cohortDefinitionSet)) {
      newSql <- VaTools::translateToCustomVaSqlText(cohortDefinitionSet$sql[i], NULL)         
      cohortDefinitionSet$sql[i] <- newSql
    }
  }
 
  negativeControlOutcomeSettings <- private$.createNegativeControlOutcomeSettingsFromJobContext()
  resultsFolder <- jobContext$moduleExecutionSettings$resultsSubFolder
  if (!dir.exists(resultsFolder)) {
    dir.create(resultsFolder, recursive = TRUE)
  }
 
  CohortGenerator::runCohortGeneration(
    connectionDetails = connectionDetails,
    cdmDatabaseSchema = jobContext$moduleExecutionSettings$cdmDatabaseSchema,
    cohortDatabaseSchema = jobContext$moduleExecutionSettings$workDatabaseSchema,
    cohortTableNames = jobContext$moduleExecutionSettings$cohortTableNames,
    cohortDefinitionSet = cohortDefinitionSet,
    negativeControlOutcomeCohortSet = negativeControlOutcomeSettings$cohortSet,
    occurrenceType = negativeControlOutcomeSettings$occurrenceType,
    detectOnDescendants = negativeControlOutcomeSettings$detectOnDescendants,
    outputFolder = resultsFolder,
    databaseId = jobContext$moduleExecutionSettings$databaseId,
    incremental = jobContext$settings$incremental,
    incrementalFolder = jobContext$moduleExecutionSettings$workSubFolder
  )
 
  private$.message(paste("Results available at:", resultsFolder))
}
 
# Stand-alone execution the CG Module
cgModule$execute(
  connectionDetails = connectionDetails,
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings
)
 
# Remove CG module from the analysis specification
analysisSpecifications$moduleSpecifications <- analysisSpecifications$moduleSpecifications[2:5]
 
## VA SPECIFIC CODE END ---------
 
Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
 
