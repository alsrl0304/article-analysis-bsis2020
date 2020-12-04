##############################################################
# 기간별로 Topic 비중의 변화를 분석                            #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "Gibbs Sampling 모델 RData 파일",
    'period', 'p', 1, 'integer', "분석 단위 기간 1: 일별 | 2: 월별 | 3: 연도별 (기본값 1)",
    'output', 'o', 1, 'character', "기간별 Topic 비중 변화 csv 파일 (기본값 trends_{input}.csv)"
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

cat(paste("\nTopic 변화", switch(periodSelect, " 일별", " 월별", " 연도별"), " 분석 실시.\n", sep=''))

cat("\n기간별 Topic 변화 추적... ")

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

cat("[완료]")

write.table(trendsMeanDataFrame, trendsFileName, sep=",", row.names = FALSE, fileEncoding="UTF-8")
cat("\n")