library(data.table)
library(raster)
library(sf)
library(SpaDES)
library(reproducible)
library(LandR)


googledrive::drive_auth("ianmseddy@gmail.com")


paths <- list(inputPath = 'inputs',
         outputPath = 'outputs',
         cachePath = 'cache',
         modulePath = 'modules') #I set this up wrong

do.call(setPaths, paths)

studyArea <- prepInputs(url = 'https://drive.google.com/file/d/16dHisi-dM3ryJTazFHSQlqljVc0McThk/view?usp=sharing',
                        destinationPath = paths$inputPath,
                        useCache = TRUE,
                        userTags = c("studyArea"))
studyArea <- rgeos::gUnaryUnion(studyArea)
studyArea$studyAreaName <- 'FtStJohn'

#cache bug work around for now

studyAreaLarge <- buffer(studyArea, 100000) #note if you supply RTM or SA, you must supply all 4 to Biomass_speciesData
studyAreaLarge$studyAreaName <- "buffFtStJohn" #make into spdf from sp

rtml <- Cache(prepInputs, url = paste0("http://ftp.maps.canada.ca/pub/nrcan_rncan/Forests_Foret/",
                                         "canada-forests-attributes_attributs-forests-canada/",
                                         "2001-attributes_attributs-2001/",
                                         "NFI_MODIS250m_2001_kNN_Structure_Biomass_TotalLiveAboveGround_v1.tif"),
              destinationPath = paths$inputPath,
              studyArea = studyAreaLarge)
studyAreaLarge <- spTransform(studyAreaLarge, CRSobj = crs(rtml))
rtm <- postProcess(rtml, studyArea = studyArea)
studyArea <- spTransform(studyArea, CRSobj = crs(rtm))


dataModules <- list("Biomass_speciesData", "Biomass_borealDataPrep",
                    "Biomass_core", "simpleHarvest")

sppEquiv <- LandR::sppEquivalencies_CA
sppEquiv <- sppEquiv[LandR %in% c("Popu_tre", "Betu_pap",
                                  "Pinu_con", "Pice_mar",
                                  "Pice_gla", "Pice_eng",
                                  "Abie_las"),]
thlb <- setValues(rtm, values = sample(x = c(0,1), size = ncell(rtm), replace = TRUE))
thlb <- mask(thlb, studyArea)
#make sure non-forest isn't harvestable

#Now we don't want Pinu_con_con
sppEquiv <- sppEquiv[!LANDIS_traits == "PINU.CON.CON"]
sppEquiv
sppColors <- LandR::sppColors(sppEquiv, sppEquivCol = "LandR", palette = "Accent", newVals = 'Mixed')
studyAreaName <- 'FtStJohn'
dataParams <- list(
  Biomass_speciesData = list(
    .useCache = 'overwrite',
    sppEquivCol = "LandR",
    .studyAreaName = studyAreaName
    # demoMode = TRUE
  ),
  Biomass_borealDataPrep = list(
    sppEquivCol = "LandR",
    .studyAreaName = studyAreaName,
    speciesTableAreas = c("MC", "BC", "BSE")
  ),
  Biomass_core = list(
    sppEquivCol = 'LandR',
    keepClimateCols = TRUE,
    successionTimestep = 1,
    .useCache = 'overwrite',
    .studyAreaName = studyAreaName,
    .plotInitialTime = NA,
    growthAndMortalityDrivers = "LandR"
  )
)

dataObjects <- list(
  studyArea = studyArea,
  studyAreaLarge = studyAreaLarge,
  rasterToMatch = rtm,
  rasterToMatchLarge = rtml,
  sppEquiv = sppEquiv,
  sppColorVect = sppColors,
  thlb = thlb
)

outputs <- data.frame(objectName = "rstCurrentHarvest", saveTime = 2011:2021, eventPriority = 10)

dataTest <- simInit(
  times = list(start = 2011, end = 2021),
  modules = dataModules,
  outputs = outputs,
  objects = dataObjects,
  params = dataParams)

dataOut <- spades(dataTest)

outHarvest <- list.files(outputPath(dataOut), pattern = "rstCurrentHarvest*", full.names = TRUE) %>%
  lapply(., readRDS) %>%
  raster::stack(.) %>%
  raster::calc(fun = sum)
plot(outHarvest)
