nws$article = gsub(' 코로나바이러스 ', ' ', nws$article);
nws$article = gsub(' 예정 ', ' ', nws$article);
nws$article = gsub(' 이날 ', ' ', nws$article);
nws$article = gsub(' 신종 ', ' ', nws$article);
nws$article = gsub(' 연합뉴스 ', ' ', nws$article);
nws$article = gsub(' 사진 ', ' ', nws$article);
nws$article = gsub(' 이라 ', ' ', nws$article);
nws$article = gsub(' 이번 ', ' ', nws$article);
nws$article = gsub(' 오후 ', ' ', nws$article);
nws$article = gsub(' 오전 ', ' ', nws$article);