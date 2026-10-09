"""Exercise the actual installed local model with synthetic inputs only."""
import json
import time
from pathlib import Path
import server

def main():
    results=[]
    def run(label,question,history=()):
        start=time.monotonic()
        result=server.answer(dict(question=question,adult=True,
            facts='Erwachsener Testnutzer. Richtwert 2670 kcal, bisher 424 kcal erfasst. Eiweißrichtwert 96 g. Keine medizinischen Angaben.',
            history=list(history)),'qwen3.5:4b',online=False)
        results.append(dict(case=label,seconds=round(time.monotonic()-start,2),response=result))
        print(label+': '+json.dumps(result,ensure_ascii=False),flush=True)
        return result
    ambiguous=run('Rückfrage','Ich habe zwei belegte Brötchen gegessen.')
    assert not ambiguous['items'] or any(x['amount'] is None or x['uncertain'] for x in ambiguous['items'])
    breakfast=run('Explizite Mengen','Heute um 8 Uhr habe ich 60 g Haferflocken, 200 ml Milch und eine Banane gegessen. Bitte erfassen.')
    assert breakfast['intent']=='meal' and len(breakfast['items'])==3
    values={i['candidates'][0]['id']:i for i in breakfast['items'] if len(i['candidates'])==1}
    assert set(values)=={'haferflocken','milch','banane'},values
    assert values['haferflocken']['amount']==60 and values['milch']['amount']==200
    assert values['banane']['unit']=='piece' and values['banane']['amount']==1
    total=sum(i['amount']*(i['candidates'][0]['portion'] if i['unit']=='piece' else 1)*i['candidates'][0]['per100']['kcal']/100 for i in values.values())
    assert abs(total-424)<.01,total
    run('Rückfrage beantworten','Es waren insgesamt 120 g Brötchen und 60 g Gouda, ohne Butter.',
        [{'role':'user','content':'Ich habe zwei belegte Brötchen gegessen.'},{'role':'assistant','content':ambiguous['reply']}])
    advice=run('Vorschlag ohne Speichern','Was könnte ich morgen proteinreich frühstücken?')
    assert advice['intent']!='meal' and advice['items']==[]
    run('Berechnete Werte erklären','Wie viele Kalorien sind bis zu meinem Richtwert noch offen?')
    (Path(__file__).parent/'.local/live-check.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print('PASS: real local model, clarification, 424-kcal database calculation, follow-up context and non-saving suggestions.')

if __name__=='__main__':main()
