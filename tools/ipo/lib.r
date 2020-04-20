#@author G. Le Corguille
# solve an issue with batch if arguments are logical TRUE/FALSE
parseCommandArgs <- function(...) {
    args <- batch::parseCommandArgs(...)
    for (key in names(args)) {
        if (args[key] %in% c("TRUE","FALSE"))
            args[key] = as.logical(args[key])
    }
    return(args)
}

#@author G. Le Corguille
# This function will
# - load the packages
# - display the sessionInfo
loadAndDisplayPackages <- function(pkgs) {
    for(pkg in pkgs) suppressPackageStartupMessages( stopifnot( library(pkg, quietly=TRUE, logical.return=TRUE, character.only=TRUE)))
    sessioninfo = sessionInfo()
    cat(sessioninfo$R.version$version.string,"\n")
    cat("Main packages:\n")
    for (pkg in names(sessioninfo$otherPkgs)) { cat(paste(pkg,packageVersion(pkg)),"\t") }; cat("\n")
    cat("Other loaded packages:\n")
    for (pkg in names(sessioninfo$loadedOnly)) { cat(paste(pkg,packageVersion(pkg)),"\t") }; cat("\n")
}

##
## This function launch IPO functions to get the best parameters for xcmsSet
## A sample among the whole dataset is used to save time
##
ipo4xcmsSet = function(directory, parametersOutput, args, samplebyclass=4) {
    setwd(directory)

    files = list.files(".", recursive=T)  # "KO/ko15.CDF" "KO/ko16.CDF" "WT/wt15.CDF" "WT/wt16.CDF"
    files = files[!files %in% c("conda_activate.log", "log.txt")]
    files_classes = basename(dirname(files))    # "KO", "KO", "WT", "WT"

    mzmlfile = files
    if (samplebyclass > 0) {
        #random selection of N files for IPO in each class
        classes<-unique(basename(dirname(files)))
        mzmlfile = NULL
        for (class_i in classes){
            files_class_i = files[files_classes==class_i]
            if (samplebyclass > length(files_class_i)) {
                mzmlfile = c(mzmlfile, files_class_i)
            } else {
                mzmlfile = c(mzmlfile,sample(files_class_i,samplebyclass))
            }
        }
    }
    #@TODO: else, must we keep the RData to been use directly by group?

    cat("\t\tSamples used:\n")
    print(mzmlfile)

    peakpickingParameters = getDefaultXcmsSetStartingParams(args$method) #get default parameters of IPO

    # filter args to only get releavant parameters and complete with those that are not declared
    peakpickingParametersUser = c(args[names(args) %in% names(peakpickingParameters)], peakpickingParameters[!(names(peakpickingParameters) %in% names(args))])
    peakpickingParametersUser$verbose.columns = TRUE
    #peakpickingParametersUser$profparam <- list(step=0.005) #not yet used by IPO have to think of it for futur improvement
    resultPeakpicking = optimizeXcmsSet(mzmlfile, peakpickingParametersUser, nSlaves=args$nSlaves, subdir="../IPO_results") #some images generated by IPO

    # export
    resultPeakpicking_best_settings_parameters = resultPeakpicking$best_settings$parameters[!(names(resultPeakpicking$best_settings$parameters) %in% c("nSlaves","verbose.columns"))]
    write.table(t(as.data.frame(resultPeakpicking_best_settings_parameters)), file=parametersOutput,  sep="\t", row.names=T, col.names=F, quote=F)  #can be read by user

    return (resultPeakpicking$best_settings$xset)
}

##
## This function launch IPO functions to get the best parameters for group and retcor
##
ipo4retgroup = function(xset, directory, parametersOutput, args, samplebyclass=4) {
    setwd(directory)

    files = list.files(".", recursive=T)  # "KO/ko15.CDF" "KO/ko16.CDF" "WT/wt15.CDF" "WT/wt16.CDF"
    files = files[!files %in% c("conda_activate.log", "log.txt")]
    files_classes = basename(dirname(files))    # "KO", "KO", "WT", "WT"

    retcorGroupParameters = getDefaultRetGroupStartingParams(args$retcorMethod) #get default parameters of IPO
    print(retcorGroupParameters)
    # filter args to only get releavant parameters and complete with those that are not declared
    retcorGroupParametersUser = c(args[names(args) %in% names(retcorGroupParameters)], retcorGroupParameters[!(names(retcorGroupParameters) %in% names(args))])
    print("retcorGroupParametersUser")
    print(retcorGroupParametersUser)
    resultRetcorGroup = optimizeRetGroup(xset, retcorGroupParametersUser, nSlaves=args$nSlaves, subdir="../IPO_results") #some images generated by IPO

    # export
    resultRetcorGroup_best_settings_parameters = resultRetcorGroup$best_settings
    write.table(t(as.data.frame(resultRetcorGroup_best_settings_parameters)), file=parametersOutput,  sep="\t", row.names=T, col.names=F, quote=F)  #can be read by user
}



# This function check if XML contains special caracters. It also checks integrity and completness.
#@author Misharl Monsoor misharl.monsoor@sb-roscoff.fr ABiMS TEAM
checkXmlStructure <- function (directory) {
  cat("Checking XML structure...\n")

  cmd <- paste0("IFS=$'\n'; for xml in $(find '",directory,"' -not -name '\\.*' -not -path '*conda-env*' -type f -iname '*.*ml*'); do if [ $(xmllint --nonet --noout \"$xml\" 2> /dev/null; echo $?) -gt 0 ]; then echo $xml;fi; done;")
  capture <- system(cmd, intern=TRUE)

  if (length(capture)>0){
    #message=paste("The following mzXML or mzML file is incorrect, please check these files first:",capture)
    write("\n\nERROR: The following mzXML or mzML file(s) are incorrect, please check these files first:", stderr())
    write(capture, stderr())
    stop("ERROR: xcmsSet cannot continue with incorrect mzXML or mzML files")
  }

}


# This function get the raw file path from the arguments
#@author Gildas Le Corguille lecorguille@sb-roscoff.fr
getRawfilePathFromArguments <- function(singlefile, zipfile, args, prefix="") {
  if (!(prefix %in% c("","Positive","Negative","MS1","MS2"))) stop("prefix must be either '', 'Positive', 'Negative', 'MS1' or 'MS2'")

  if (!is.null(args[[paste0("zipfile",prefix)]])) zipfile <- args[[paste0("zipfile",prefix)]]

  if (!is.null(args[[paste0("singlefile_galaxyPath",prefix)]])) {
    singlefile_galaxyPaths <- args[[paste0("singlefile_galaxyPath",prefix)]]
    singlefile_sampleNames <- args[[paste0("singlefile_sampleName",prefix)]]
  }
  if (exists("singlefile_galaxyPaths")){
    singlefile_galaxyPaths <- unlist(strsplit(singlefile_galaxyPaths,"\\|"))
    singlefile_sampleNames <- unlist(strsplit(singlefile_sampleNames,"\\|"))

    singlefile <- NULL
    for (singlefile_galaxyPath_i in seq(1:length(singlefile_galaxyPaths))) {
      singlefile_galaxyPath <- singlefile_galaxyPaths[singlefile_galaxyPath_i]
      singlefile_sampleName <- singlefile_sampleNames[singlefile_galaxyPath_i]
      # In case, an url is used to import data within Galaxy
      singlefile_sampleName <- tail(unlist(strsplit(singlefile_sampleName,"/")), n=1)
      singlefile[[singlefile_sampleName]] <- singlefile_galaxyPath
    }
  }
  return(list(zipfile=zipfile, singlefile=singlefile))
}

# This function retrieve the raw file in the working directory
#   - if zipfile: unzip the file with its directory tree
#   - if singlefiles: set symlink with the good filename
#@author Gildas Le Corguille lecorguille@sb-roscoff.fr
retrieveRawfileInTheWorkingDirectory <- function(singlefile, zipfile) {
    if(!is.null(singlefile) && (length("singlefile")>0)) {
        for (singlefile_sampleName in names(singlefile)) {
            singlefile_galaxyPath <- singlefile[[singlefile_sampleName]]
            if(!file.exists(singlefile_galaxyPath)){
                error_message <- paste("Cannot access the sample:",singlefile_sampleName,"located:",singlefile_galaxyPath,". Please, contact your administrator ... if you have one!")
                print(error_message); stop(error_message)
            }

            if (!suppressWarnings( try (file.link(singlefile_galaxyPath, singlefile_sampleName), silent=T)))
                file.copy(singlefile_galaxyPath, singlefile_sampleName)

        }
        directory <- "."

    }
    if(!is.null(zipfile) && (zipfile != "")) {
        if(!file.exists(zipfile)){
            error_message <- paste("Cannot access the Zip file:",zipfile,". Please, contact your administrator ... if you have one!")
            print(error_message)
            stop(error_message)
        }

        #list all file in the zip file
        #zip_files <- unzip(zipfile,list=T)[,"Name"]

        #unzip
        suppressWarnings(unzip(zipfile, unzip="unzip"))

        #get the directory name
        suppressWarnings(filesInZip <- unzip(zipfile, list=T))
        directories <- unique(unlist(lapply(strsplit(filesInZip$Name,"/"), function(x) x[1])))
        directories <- directories[!(directories %in% c("__MACOSX")) & file.info(directories)$isdir]
        directory <- "."
        if (length(directories) == 1) directory <- directories

        cat("files_root_directory\t",directory,"\n")

    }
    return (directory)
}


# This function retrieve a xset like object
#@author Gildas Le Corguille lecorguille@sb-roscoff.fr
getxcmsSetObject <- function(xobject) {
    # XCMS 1.x
    if (class(xobject) == "xcmsSet")
        return (xobject)
    # XCMS 3.x
    if (class(xobject) == "XCMSnExp") {
        # Get the legacy xcmsSet object
        suppressWarnings(xset <- as(xobject, 'xcmsSet'))
        if (!is.null(xset@phenoData$sample_group))
            sampclass(xset) <- xset@phenoData$sample_group
        else
            sampclass(xset) <- "."
        return (xset)
    }
}