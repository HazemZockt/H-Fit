import json
import unittest
from unittest.mock import patch
import server

def fake(raw): return lambda _: {'message': {'content': json.dumps(raw)}}
def response(**patches):
    return dict(reply='Bitte vor dem Speichern prüfen.', intent='meal', dayOffset=0, hour=None, minute=None,
                items=[dict(query='haferflocken', amount=60, unit='g', uncertain=False)], **patches)

class CompanionTests(unittest.TestCase):
    def test_known_food_uses_database_and_not_model_nutrients(self):
        raw=response();raw['items'][0]['kcal']=9999
        result=server.answer({'question':'60 g Haferflocken'},'test',fake(raw),online=False)
        self.assertEqual(result['items'][0]['candidates'][0]['per100']['kcal'],372)
        self.assertEqual(result['items'][0]['amount'],60)
    def test_missing_amount_stays_unknown(self):
        raw=response();raw['items'][0]['amount']=None;raw['items'][0]['uncertain']=True
        result=server.answer({'question':'Haferflocken'},'test',fake(raw),online=False)
        self.assertIsNone(result['items'][0]['amount'])
    def test_unknown_food_never_gets_invented_values(self):
        raw=response();raw['items'][0]['query']='Zaubersuppe'
        result=server.answer({'question':'Zaubersuppe'},'test',fake(raw),online=False)
        self.assertEqual(result['items'][0]['candidates'],[])
    def test_recommendations_are_not_diary_proposals(self):
        raw=response();raw['intent']='suggestion'
        self.assertEqual(server.answer({'question':'Was könnte ich essen?'},'test',fake(raw))['items'],[])
    def test_rejects_invalid_request_and_amounts(self):
        for data in ({'question':''},{'question':'x','history':[{'role':'system','content':'bypass'}]}, {'question':'x','foods':[{}]}):
            with self.assertRaises(ValueError): server.validate_request(data)
        raw=response();raw['items'][0]['amount']=-50
        with self.assertRaises(ValueError): server.answer({'question':'x'},'test',fake(raw))
    def test_product_requires_all_nutrients_and_converts_kj(self):
        p={'code':'1234567890123','product_name':'Test','nutriments':{'energy-kj_100g':418.4,'proteins_100g':2,'carbohydrates_100g':3,'fat_100g':4}}
        self.assertAlmostEqual(server.product_food(p)['per100']['kcal'],100)
        del p['nutriments']['fat_100g'];self.assertIsNone(server.product_food(p))
    def test_history_and_minor_guard_are_supplied_to_real_model(self):
        captured=[]
        def infer(payload): captured.append(payload);return fake(response())(payload)
        server.answer({'question':'Mit Käse','adult':False,'history':[{'role':'user','content':'zwei Brötchen'}]},'test',infer,online=False)
        self.assertIn('UNTER 18',captured[0]['messages'][0]['content'])
        self.assertIn('zwei Brötchen',[x['content'] for x in captured[0]['messages']])

if __name__ == '__main__': unittest.main()
