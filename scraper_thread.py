import threading
import csv
from queue import Queue
from press_scraper import Scraper

class CollectThread(threading.Thread):
    def __init__(self, scraper, number_of_articles, query_word, detail_word, queue, list_file_name):
        threading.Thread.__init__(self)
        self.scraper = scraper
        self.queue = queue
        self.list_file_name = list_file_name
        self.number_of_articles, self.query_word, self.detail_word = number_of_articles, query_word, detail_word

        self.num = 1 # 횟수 카운터

    def run(self):
        with open(self.list_file_name, 'w', encoding='utf8') as file_list:
            file_list.write('"url", "title"')

            for article in self.scraper.collect_articles(self.number_of_articles, self.query_word, self.detail_word):
                #파일에 기록
                file_list.write(f'{article["url"]}, "{article["title"]}"\n')
                
                #작업 큐에 저장
                self.queue.put(article)

                # 작업 상황 출력
                print(f'Collecting [{self.num}] {article["url"]}')
                self.num += 1



class ScrapThread(threading.Thread):
    def __init__(self, scraper, number_of_articles, queue, result_file_name):
        threading.Thread.__init__(self)
        self.scraper = scraper
        self.queue = queue
        self.result_file_name = result_file_name
        self.number_of_articles = number_of_articles

        self.num = 1 # 횟수 카운터

    def run(self):
        with open(self.result_file_name, 'w', encoding='utf8') as file_result:
            file_result.write('"date", "title", "body"')

            for _ in range(self.number_of_articles):
                #작업 큐에서 받아옴
                article = self.queue.get()

                url = article['url']
                content = self.scraper.scrap_articles(url)  # 내용 스크랩
                file_result.write(f'"{content["date"]}", "{content["title"]}", "{content["body"]}"\n')  # 파일 작성

                # 작업 상황 출력
                print(f'Scraping [{self.num}] {url}')
                self.num += 1