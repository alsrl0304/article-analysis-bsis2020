##############################################################
# 워드 클라우드 생성                                          #
##############################################################

###################### 명령행 인수 파싱 #######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "상위 단어 csv 파일",
    'output', 'o', 1, 'character', "워드클라우드 웹 문서 경로 (기본값 ./wordcloud_{input}/)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if(!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

frequentFileName <- opts$input
cloudDirName <- opts$output

if (is.null(frequentFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(cloudDirName)) {
    cloudDirName <- paste("./wordcloud", file_path_sans_ext(basename(frequentFileName)), sep="_")
}

###################### 워드클라우드 생성 #######################
library(wordcloud2)
library(htmlwidgets)

selectedWordsMat <- read.csv(frequentFileName, header = TRUE, fileEncoding = "UTF-8", stringsAsFactors=FALSE)
cat("\n상위 단어", length(selectedWordsMat[,1]), " 개로 작업 실시.\n", sep='')


cat("\n워드클라우드 생성 중... ")
# 선택된 단어로 워드 클라우드 생성
# size : 클라우드 크기, col : 글자색상 변경 옵션
# rotateRatio :글자 기울기 허용 각도, backgroundColor : 배경색
cloud <- wordcloud2(selectedWordsMat)
#wordcloud2(selectedWordsMat, size=1.0, shape = 'diamond', col="random-dark", rotateRatio = 0)
#wordcloud2(selectedWordsMat, size=0.5, col="random-light", rotateRatio = 0.3, backgroundColor="gray")
cat("[완료]")

# 워드클라우드 저장
oriWorkDir <- getwd() #현재 작업 위치 저장
dir.create(cloudDirName, showWarnings=FALSE) # 목표 디렉터리 생성
setwd(cloudDirName) # 작업 위치 변경
saveWidget(cloud, "wordcloud.html", selfcontained = FALSE) # 워드클라우드 저장
setwd(oriWorkDir) # 작업 위치 복원
cat("\n\n작업 완료.\n")
