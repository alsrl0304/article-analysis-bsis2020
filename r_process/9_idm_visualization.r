############################################################## 
# 전 기간에 대한 토픽별 상관 관계 분석 IDM 생성                 #
##############################################################

####################### 명령행 인수 처리 ######################
library(getopt)
library(tools)

argSpec <- matrix(c(
    'help', 'h', 0, 'logical', "도움말",
    'input', 'i', 1, 'character', "Gibbs Sampling 모델 RData 파일",
    'output', 'o', 1, 'character', "IDM 웹 문서 경로 (기본값 ./IDM_{input}/)"
), byrow=TRUE, ncol=5)

opts <- getopt(argSpec)

if (!is.null(opts$help)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

modelFileName <- opts$input
idmDirName <- opts$output

if (is.null(modelFileName)) {
    cat(getopt(argSpec, usage=TRUE))
    q(status=1)
}

if (is.null(idmDirName)) {
    idmDirName <- paste("IDM", file_path_sans_ext(basename(modelFileName)), sep="_")
}

##################### IDM 시각화 자료 생성 ####################
library(rJava)
library(stringr)
library(SnowballC)
library(servr)
library(tm)
library(topicmodels)
library(lda)
library(archivist) # Tools for Storing, Restoring and Searching for R Objects
library(LDAvis) # IDM 등의 LDA 결과를 시각화 하는데 필요한 라이브러리


set.seed(42135798)
# 앞서 분석할 때 사용한 초기 시드값을 사용함으로써 
# 새로 수행할 경우 오차가 크게 발생하지 않음

cat("\n기사 Document Term Matrix 생성... ")

# articlesDataFrame: $date (작성일), $title (제목), $body (기사 본문)
load(modelFileName)

corpusArticles <- VCorpus(VectorSource(articlesDataFrame$body))
tdmArticles <- TermDocumentMatrix(corpusArticles, control=list(wordLengths=c(1, Inf)))
matArticles <- as.matrix(tdmArticles)

orderedWordsVector <- order(rowSums(matArticles), decreasing = TRUE)

# 상위 wordsNum개의 단어로 군집화에 사용될 document-term 매트릭스 생성
dtmArticles <- as.DocumentTermMatrix(tdmArticles[orderedWordsVector[1:wordsNum],])

cat("[완료]")

cat("\nIDM 문서 생성... ")
# 이상 2개의 파라미터 값은 LDA 분석에 사용한 것과 같은 값을 사용하여야
# 새로 처리하는 경우에도 추출되는 토픽별 단어에 큰 변동이 없음

theta <- t(apply(gibbsResult$document_sums + gibbs_alpha, 2, function(x) x/sum(x)))
phi <- t(apply(t(gibbsResult$topics) + gibbs_eta, 2, function(x) x/sum(x)))

rowTotals <- apply(dtmArticles , 1, sum)
colTotals <- apply(dtmArticles , 2, sum)

# 시각화를 위해 JSON 객체를 생성
json <- createJSON(
    phi = phi, 
    theta = theta, 
    doc.length = rowTotals, 
    vocab = colnames(dtmArticles),
    term.frequency = colTotals, R=wordsNum, lambda.step = 0.01, mds.method = jsPCA)
# R : map에 표시할 토픽별 단어 개수
cat("[완료]")

# 생성된 json 파일과 관련 시각화 파일들을 해당 디렉토리에 생성
serVis(json, out.dir = idmDirName, encoding='UTF-8', open.browser=FALSE)

cat("\n")
