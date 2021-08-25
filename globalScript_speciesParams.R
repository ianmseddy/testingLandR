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
              modulePath = c('modules'))

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
                    "PSP_Clean",
                    "Biomass_speciesParameters",
                    "Biomass_core")

sppEquiv <- LandR::sppEquivalencies_CA
sppEquiv <- sppEquiv[LandR %in% c("Abie_las", "Popu_tre", "Betu_pap",
                                  "Pinu_con", "Pice_mar", "Pice_gla", "Pice_eng"),]

#Now we don't want Pinu_con_con
sppEquiv <- sppEquiv[!LANDIS_traits == "PINU.CON.CON"]
sppColors <- LandR::sppColors(sppEquiv, sppEquivCol = "LandR", palette = "Accent", newVals = 'Mixed')
studyAreaName <- 'FtStJohn'

#species pararam udpate
RIASppUpdate <- function(sT) {
  sT[species == "Abie_las", longevity := 300]
  sT[species == "Betu_pap", longevity := 150]
  sT[, shadetolerance := as.numeric(shadetolerance)]
  sT[species == 'Pice_eng', shadetolerance := 2.5]
  sT[species == 'Pice_mar', shadetolerance := 2.5]
  sT[species == "Pice_mar", longevity := 200]
  sT[species == "Pice_gla", longevity := 250]
  sT[species == "Pinu_con", longevity := 300]
  sT[species == "Pice_eng", longevity := 300 ]
  return(sT)
}



dataParams <- list(
  Biomass_speciesData = list(
    sppEquivCol = "LandR",
    .studyAreaName = studyAreaName
  ),
  Biomass_borealDataPrep = list(
    sppEquivCol = "LandR",
    speciesUpdateFunction = list(
      quote(LandR::speciesTableUpdate(sim$species, sim$speciesTable, sim$sppEquiv, P(sim)$sppEquivCol)),
      quote(LandR::updateSpeciesTable(sim$species, sim$speciesParams)),
      quote(RIASppUpdate(sT = sim$species))
    ),
    .studyAreaName = studyAreaName,
    speciesTableAreas = c("MC", "BC", "BSE")
  ),
  Biomass_core = list(
    sppEquivCol = 'LandR',
    successionTimestep = 10,
    .studyAreaName = studyAreaName,
    .plotInitialTime = NA,
    growthAndMortalityDrivers = "LandR"
  ),
  Biomass_speciesParameters = list(
      "sppEquivCol" = "LandR",
      " useHeight" = FALSE,
      "GAMMknots" = list(
        "Abie_las" = 3,
        "Betu_pap" = 3,
        "Pice_eng" = 4,
        "Pice_gla" = 3,
        "Pice_mar" = 4,
        "Pinu_con" = 4,
        "Popu_tre" = 4
      ),
      constrainMaxANPP = c(3.0, 4.0),
      constrainGrowthCurve = c(0, 1),
      constrainMortalityShape = list(
        "Abie_las" = c(15, 25),
        "Betu_pap" = c(15, 25),
        "Pice_eng" = c(15, 25),
        "Pice_gla" = c(15, 25),
        "Pice_mar" = c(15, 25),
        "Pinu_con" = c(15, 25),
        "Popu_tre" = c(15, 25) #changed from 20,25
      ),
      quantileAgeSubset = list(
        "Abie_las" = 95, #N = 250 ''
        "Betu_pap" = 95, #N = 96
        "Pice_eng" = 95, #N = 130
        "Pice_gla" = 95, #N = 1849
        "Pice_mar" = 95, #N = 785
        "Pinu_con" = 97, # N = 3172
        "Popu_tre" = 99 # N = 1997
      )
  ),
  Biomass_regeneration = list(
    successionTimestep = 10
  )
)

dataObjects <- list(
  studyArea = studyArea,
  studyAreaLarge = studyAreaLarge,
  rasterToMatch = rtm,
  rasterToMatchLarge = rtml,
  sppEquiv = sppEquiv,
  sppColorVect = sppColors
)


mySim <- simInit(
  times = list(start = 2011, end = 2021),
  modules = dataModules,
  objects = dataObjects,
  params = dataParams)

mySimOut <- spades(mySim)

