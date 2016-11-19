
testCategoricalMultiple <- function(varName, varType, thisdata) {
	cat("CAT-MULTIPLE || ");

	pheno = thisdata[,phenoStartIdx:ncol(thisdata)]

	pheno = reassignValue(pheno, varName)

	## get unique values from all columns of this variable
	uniqueValues = unique(na.omit(pheno[,1]));
	numCols = ncol(pheno);
	numRows = nrow(pheno);
	for (num in 2:numCols) {
		u = unique(na.omit(pheno[,num]))
		uniqueValues = union(uniqueValues,u);
	}

	## for each value create a binary variable and test this
	for (variableVal in uniqueValues) {


		## numeric negative values we assume are missing - check this
		if(is.numeric(variableVal) & variableVal<0) {
			cat("SKIP_val:", variableVal," < 0", sep="");
			next;
		}
	
		# make variable for this value
		idxForVar = which(pheno == variableVal, arr.ind=TRUE)

		cat(" CAT-MUL-BINARY-VAR ", variableVal, " || ", sep="");
		count$catMul.binary <<- count$catMul.binary+1;
		
		# make zero vector and set 1s for those with this variable value
		varBinary = rep.int(0,numRows);
		varBinary[idxForVar] = 1;
		varBinaryFactor = factor(varBinary)

		## data for this new binary variable
		newthisdata = cbind.data.frame(thisdata[,1:numPreceedingCols], varBinaryFactor)

		## one of 3 ways to decide which examples are negative
        	idxsToRemove = restrictSample(varName, pheno, variableVal);	
		if (!is.null(idxsToRemove)) {
			newthisdata = newthisdata[-idxsToRemove,]
		}

		facLevels = levels(newthisdata[,phenoStartIdx])		
		idxTrue = length(which(newthisdata[,phenoStartIdx]==facLevels[1]))
        idxFalse = length(which(newthisdata[,phenoStartIdx]==facLevels[2]))
                
        if (idxTrue<10 || idxFalse<10) {
                cat("CAT-MULT-SKIP-10 (", idxTrue, " vs ", idxFalse, ") || ", sep="");
                count$catMul.10 <<- count$catMul.10+1;
                next;
        }
		else {
			count$catMul.over10 <<- count$catMul.over10+1;
            # binary - so logistic regression
			binaryLogisticRegression(paste(varName, variableVal,sep="#"), varType, newthisdata)
		}
	}
}


restrictSample <- function(varName,pheno,variableVal) {

	# get definition for sample for this variable either NO_NAN, ALL or a variable ID
	varIndicator = vl$phenoInfo$CAT_MULT_INDICATOR_FIELDS[which(vl$phenoInfo$FieldID==varName)]

	return(restrictSample2(varName,pheno,varIndicator,variableVal))
}


restrictSample2 <- function(varName,pheno, varIndicator,variableVal) {
	
	if (varIndicator=="NO_NAN") { # remove NAs
		## remove all people with no value for this variable
		
		ind <- apply(pheno, 1, function(x) all(is.na(x)))
		#cat(which(ind==TRUE))
		naIdxs = which(ind==TRUE)
		cat("NO_NAN Remove NA participants ", length(naIdxs), " || ", sep="");
	}
	else if (varIndicator=="ALL") {
		# hospital data so use all people (no missing assumed) .. also for death registry
		naIdxs = cbind()
		cat("ALL || ")
	}
	else if (varIndicator!="") {
		# remove people who have no value for indicator variable
		indName = paste("x",varIndicator,"_0_0",sep="");
		cat("Indicator name ", indName, " || ", sep="");
		indicatorVar = data[,indName]

		# remove participants with NA value in this related field
		indicatorVar = replaceNaN(indicatorVar)
		naIdxs = which(is.na(indicatorVar))

		cat("Remove indicator var NAs: ", length(naIdxs), " || ", sep="");

		if (is.numeric(as.matrix(indicatorVar))) {
			# remove participants with value <0 in this related field
			lessZero = which(indicatorVar<0)
			naIdxs = union(naIdxs, lessZero)
			cat("Remove indicator var <0: ", length(lessZero), " || ", sep="")
		}
	}
	else {
		stop("Categorical multiples variables need a value for CAT_MULT_INDICATOR_FIELDS", call.=FALSE)
	}

	## remove people with pheno<0 if they aren't a positive example for this variable indicator
	## because we can't know if they are a negative example or not

	if (is.numeric(as.matrix(pheno))) {
		idxForVar = which(pheno == variableVal, arr.ind=TRUE)
		idxMissing = which(pheno < 0, arr.ind=TRUE)
		naMissing = setdiff(idxMissing,idxForVar)
		naIdxs = union(naIdxs, naMissing)
		cat(paste("Removed ", length(naMissing) ," examples != ", variableVal, " but with missing value (<0) || ", sep=""));
	}
	else {
		cat("Not numeric || ")
	}
	
	return(naIdxs);

}

