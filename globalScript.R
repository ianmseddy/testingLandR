library(reproducible)
library(LandR)
library(raster)
library(SpaDES)

googledrive::drive_auth("ianmseddy@gmail.com")

setPaths(inputPath = 'inputs',
         outputPath = 'outputs',
         cachePath = 'cache',
         modulePath = '../testingLandR') #I set this up wrong

paths <- getPaths()

studyArea <- prepInputs(url = 'https://drive.google.com/file/d/16dHisi-dM3ryJTazFHSQlqljVc0McThk/view?usp=sharing',
                        destinationPath = paths$inputPath,
                        useCache = TRUE,
                        userTags = c("studyArea"))
rasterToMatch <- prepInputsLCC(destinationPath = paths$inputPath,
                               studyArea = studyArea)
#cache bug work around for now
rasterToMatch <- setValues(raster(rasterToMatch), getValues(rasterToMatch))
studyAreaLarge <- studyArea #note if you supply RTM or SA, you must supply all 4 to Biomass_speciesData
rasterToMatchLarge <- rasterToMatch

dataModules <- list("PSP_Clean", "Biomass_speciesData", "Biomass_borealDataPrep",
                "Biomass_speciesParameters", "gmcsDataPrep")

sppEquiv <- LandR::sppEquivalencies_CA
sppEquiv <- sppEquiv[LandR %in% c("Popu_tre", "Betu_pap",
                                  "Pinu_con", "Pice_mar",
                                  "Pice_gla", "Pice_eng",
                                  "Abie_las"),]
sppColors <- sppColors(sppEquiv, sppEquivCol = "LandR", palette = "Accent")

dataParams <- list(
  Biomass_speciesData = list(
  sppEquivCol = "LandR"),
  Biomass_borealDataPrep = list(
    sppEquivCol = "LandR"),
  Biomass_speciesParameters= list(
    sppEquivCol = "LandR")
)


dataObjects <- list(studyArea = studyArea,
                    studyAreaLarge = studyAreaLarge,
                    rasterToMatch = rasterToMatch,
                    rasterToMatchLarge = rasterToMatchLarge,
                    sppEquiv = sppEquiv,
                    sppColorVect = sppColors)
dataTest <- simInit(times = list(start = 0, end = 1),
                    modules = dataModules,
                    objects = dataObjects,
                    params = dataParams)
