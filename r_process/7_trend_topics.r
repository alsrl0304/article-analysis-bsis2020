##############################################################
# 기간별로 Topic 비중의 변화를 분석                            #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "help",
    'input', 'i', 1, 'character', "Trained Gibbs Sampling Model, RData File",
    'period', 'p', 1, 'integer', "Analysis Period 1: Daily | 2: Monthly | 3: Yearly (Default 1)",
    'output', 'o', 1, 'character', "Articles Proportion Trends, CSV File (Default trends_{input}.csv)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

modelFileName <- opts$input
trendsFileName <- opts$output
periodSelect <- opts$period

if (is.null(modelFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if(is.null(periodSelect)) {
    periodSelect <- 1
}

periodFormat <- switch(periodSelect, "%Y-%m-%d", "%Y-%m", "%Y")

if (is.null(trendsFileName)) {
    trendsFileName <- paste(paste("trends",
        file_path_sans_ext(basename(modelFileName)), sep="_"), ".csv", sep='')
}

################ Topic별 기간에 따른 변화 확인 #################

cat("Analysis Trends", switch(periodSelect, "Daily", "Monthly", "Yearly"))

cat("Tracking Articles Proportion Trends... ")

load(modelFileName)

# 기간에 따른 처리의 용이성을 위해 document_sums를 data frame으로 변환 
trendsDataFrame <- as.data.frame(t(gibbsResult$document_sums), stringAsFactor=FALSE)

# 전체 값에 대해 rowSum으로 나눠서 비율값으로 변환
trendsDataFrame <- trendsDataFrame/rowSums(trendsDataFrame) 

# 분석하고자 하는 기간 단위 설정
trendsDataFrame$period <- format(as.Date(articlesDataFrame$date, format="%Y-%m-%d"), periodFormat)        

# trends에서 topic 확률의 값이 NA인 것들을 삭제
trendsDataFrame <- trendsDataFrame[which(!is.nan(trendsDataFrame$V1)),] 

# 기간별로 평균값 계산
trendsMeanDataFrame <- aggregate(trendsDataFrame, by = list(trendsDataFrame$period), FUN=mean)

# 의미가 없는 부분, 삭제
trendsMeanDataFrame$period <- NULL

# 컬럼 이름 변경
colnames(trendsMeanDataFrame)[which(colnames(trendsMeanDataFrame) == 'Group.1')] <- 'period'

cat("[DONE]\n")

write.table(trendsMeanDataFrame, trendsFileName, sep=",", row.names = FALSE, fileEncoding="UTF-8")