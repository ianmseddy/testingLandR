
library(reproducible)
library(LandR)
library(raster)
library(SpaDES)

googledrive::drive_auth("ianmseddy@gmail.com")

setPaths(inputPath = 'inputs',
         outputPath = 'outputs',
         cachePath = 'cache',
         modulePath = 'modules') #I set this up wrong

paths <- getPaths()

studyArea <- prepInputs(url = 'https://drive.google.com/file/d/16dHisi-dM3ryJTazFHSQlqljVc0McThk/view?usp=sharing',
                        destinationPath = paths$inputPath,
                        useCache = TRUE,
                        userTags = c("studyArea"))
studyArea <- rgeos::gUnaryUnion(studyArea)
studyArea$studyAreaName <- 'FtStJohn'

rtm <- prepInputsLCC(destinationPath = paths$inputPath,
                               studyArea = studyArea)
#cache bug work around for now
rtm <- setValues(raster(rtm), getValues(rtm))

studyAreaLarge <- buffer(studyArea, 100000) #note if you supply RTM or SA, you must supply all 4 to Biomass_speciesData
rtml <- prepInputsLCC(destinationPath = paths$inputPath, studyArea = studyAreaLarge)

dataModules <- list("PSP_Clean", "Biomass_speciesData", "Biomass_borealDataPrep",
                    "Biomass_speciesParameters", "gmcsDataPrep", "Biomass_core")

sppEquiv <- LandR::sppEquivalencies_CA
sppEquiv <- sppEquiv[LandR %in% c("Popu_tre", "Betu_pap",
                                  "Pinu_con", "Pice_mar",
                                  "Pice_gla", "Pice_eng",
                                  "Abie_las"),]
#Now we don't want Pinu_con_con
sppEquiv <- sppEquiv[!LANDIS_traits == "PINU.CON.CON"]
sppColors <- LandR::sppColors(sppEquiv, sppEquivCol = "LandR", palette = "Accent", newVals = 'Mixed')

dataParams <- list(
  Biomass_speciesData = list(
    .useCache = 'overwrite',
    sppEquivCol = "LandR"
    # demoMode = TRUE
  ),
  Biomass_borealDataPrep = list(
    sppEquivCol = "LandR",
    speciesTableAreas = c("MC", "BC", "BSE")
  ),
  # no traits for the Boreal Cordillera, Pice_gla missing from MC, PM full of bad estimates
  Biomass_speciesParameters= list(
    sppEquivCol = "LandR"
  ),
  Biomass_core = list(
    sppEquivCol = 'LandR',
    keepClimateCols = TRUE,
    successionTimestep = 1,
    .useCache = 'overwrite',
    .plotInitialTime = NA,
    growthAndMortalityDrivers = "LandR"
  )
)

dataObjects <- list(
  studyArea = studyArea,
  studyAreaLarge = studyAreaLarge,
  rasterToMatch = rtm,
  rasterToMatchLarge = rtml,
  sppEquiv = sppEquiv
  , sppColorVect = sppColors
)
devtools::load_all("../LandR")
dataTest <- simInit(times = list(start = 2011, end = 2012),
                    modules = dataModules,
                    objects = dataObjects,
                    params = dataParams)
dataOut <- spades(dataTest)
