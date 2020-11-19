#####################################################
# 필요 라이브러리 설치 코드                               #
#####################################################

# CRAN 미러 선택
chooseCRANmirror(graphics=FALSE, ind=48) # 부경대 미러

install.packages("rJava")
install.packages("rmarkdown")
install.packages('servr')
install.packages('archivist')
install.packages('backports')
install.packages('bit64')
install.packages("NLP")        #단어 처리를 위한 기본 함수 패키지
#install.packages("openNLP")   #영어용 추가 기능 공개용 패키지

#install.packages("KoNLP")     #한글언어 처리용 KoNLP 패키지

install.packages("tm")         #TextMining 패키지
install.packages("SnowballC")  #Snowball Stemmers 패키지
install.packages("topicmodels")#Topicmodels 패키지
install.packages("lda")        #LDA 패키지
install.packages("ggplot2")    #그래프 출력용 함수 패키지
install.packages("LDAvis")     #LDA 결과 시각화(visulization)용 패키지
install.packages("wordcloud")  #wordcloud 패키지
install.packages('wordcloud2') #wordcloud2 패키지
install.packages('tidytext')   #tidytext 패키지
install.packages('Rcpp')       #Rcpp 패키지
install.packages('slam')       #slam 패키지
install.packages('rlang')      #rlang 패키지
install.packages('vctrs')      #vctrs 패키지

# JAVA DEVELOPMENT KIT 없으면 설치
if(!is.null(Sys.getenv("JAVA_HOME"))) {
    install_jdk()
}

install.packages("multilinguer")
library(multilinguer)
install.packages(c('stringr', 'hash', 'tau', 'Sejong', 'RSQLite', 'devtools'), type = "binary")
install.packages("remotes")
remotes::install_github('haven-jeon/KoNLP', upgrade = "never", INSTALL_opts=c("--no-multiarch"))