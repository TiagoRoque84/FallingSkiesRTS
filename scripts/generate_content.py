"""Recria dados e áudio originais, sem pacotes externos. Python 3."""
import json, math, random, wave, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def unit(name, hp, speed, damage, reach, cost, time, producer, **kw):
    return dict(name=name, hp=hp, speed=speed, damage=damage, range=reach,
                cost=cost, time=time, producer=producer, radius=10, sight=320,
                cooldown=1.0, biological=True, description='', **kw)

units = {
 'mcv': unit('Comando móvel', 900, 62, 0, 0, 0, 0, '', role='mcv'),
 'worker': unit('Coletor', 260, 88, 0, 0, 220, 9, 'hq', role='worker'),
 'rifle': unit('Combatente', 110, 94, 15, 170, 100, 5, 'barracks', role='infantry'),
 'scout': unit('Batedor', 85, 155, 10, 145, 130, 6, 'barracks', role='scout'),
 'heavy': unit('Equipe antiblindado', 130, 73, 34, 215, 220, 9, 'barracks', role='antiarmor'),
 'sniper': unit('Atirador de elite', 85, 85, 40, 310, 280, 11, 'barracks', role='sniper'),
 'medic': unit('Médico', 100, 99, 0, 150, 180, 8, 'barracks', role='medic', heal=10),
 'engineer': unit('Engenheiro', 100, 95, 0, 65, 180, 8, 'barracks', role='engineer'),
 'buggy': unit('Caminhonete armada', 320, 143, 25, 190, 380, 13, 'factory', role='vehicle'),
 'tank': unit('Blindado', 650, 72, 65, 245, 650, 20, 'factory', role='armor'),
 'elite': unit('Tecnologia recuperada', 330, 100, 42, 245, 480, 16, 'barracks', role='elite', requires='lab'),
 'siege': unit('Artilharia', 340, 60, 95, 370, 720, 23, 'factory', role='siege', requires='lab'),
 'hero': unit('Herói', 700, 110, 36, 225, 800, 28, 'barracks', role='hero', requires='lab'),
 'special': unit('Batedor especial', 240, 145, 23, 195, 360, 14, 'barracks', role='special', requires='lab'),
}
for k in ('mcv','worker','buggy','tank','siege'):
    units[k]['biological'] = False
    units[k]['radius'] = 16 if k not in ('mcv', 'tank') else 21
for k in ('scout','special'): units[k]['sight'] = 480
units['mcv']['description'] = 'Implante com D para iniciar sua base.'
units['worker']['description'] = 'Coleta 90 suprimentos e retorna à refinaria. Clique direito em um depósito.'
units['heavy']['description'] = 'Dano dobrado contra veículos e estruturas.'
units['sniper']['description'] = 'Alcance longo. Eficaz contra infantaria.'
units['medic']['description'] = 'Cura aliados biológicos próximos automaticamente.'
units['engineer']['description'] = 'Repara aliados. Clique direito em um prédio inimigo danificado para capturar.'
units['hero']['description'] = 'Aura: +20% dano em 180 m. F: habilidade exclusiva; recarga 55 s.'
units['special']['description'] = 'F: interferência / conversão / saque. Recarga 35 s.'
units['siege']['description'] = 'Dano em área. Distância mínima segura: 80 m.'
units['elite']['description'] = 'Tropa avançada desbloqueada pelo laboratório.'

def building(name,hp,cost,time,power,**kw):
    return dict(name=name,hp=hp,cost=cost,time=time,power=power,radius=32,
                sight=340,damage=0,range=0,speed=0,description='',**kw)
buildings = {
 'hq': building('Centro de Comando',2400,0,0,25),
 'power': building('Gerador',650,250,12,65),
 'refinery': building('Depósito de Suprimentos',1000,500,18,-15,requires='power'),
 'barracks': building('Quartel',850,350,14,-10,requires='power'),
 'factory': building('Oficina',1200,700,24,-25,requires='barracks'),
 'lab': building('Laboratório',800,800,28,-25,requires='factory'),
 'hospital': building('Enfermaria',700,400,17,-15,requires='barracks'),
 'turret': building('Torre de Vigia',800,320,13,-15,requires='barracks'),
 'wall': building('Barricada',700,65,4,0),
 'super': building('Silo Nuclear Recuperado',1400,1800,50,-65,requires='lab'),
}
buildings['turret'].update(damage=36,range=270,cooldown=1.0)
buildings['wall']['radius']=20
buildings['super']['description']='Superarma de área. Requer energia. Recarga: 180 s (Berserkers: 140 s).'
buildings['refinery']['description']='Recebe cargas e entrega um coletor gratuito na conclusão.'
buildings['lab']['description']='Desbloqueia elites, herói e pesquisa: +15% dano (500 suprimentos).'
buildings['hospital']['description']='Cura infantaria aliada em um raio de 210 m enquanto energizada.'
names = [
 {},
 dict(hq='Núcleo Espheni',mcv='Semente de invasão',power='Coletor de Bioenergia',refinery='Extrator de destroços',barracks='Portal de Produção',factory='Fábrica de Mechs',lab='Torre de Controle',hospital='Câmara de Arnês',turret='Obelisco de Defesa',wall='Barreira alienígena',super='Nexus de Bombardeio',worker='Drone coletor',rifle='Skitter',scout='Drone Espheni',heavy='Skitter veterano',sniper='Beamer de precisão',medic='Regenerador',engineer='Unidade de captura',buggy='Beamer de ataque',tank='Mech',elite='Guerreiro híbrido',siege='Mega Mech',hero='Overlord Espheni',special='Controlador de arnês'),
 dict(hq='Esconderijo',mcv='Comboio de Pope',power='Gerador Roubado',refinery='Ferro-Velho',barracks='Tenda de Recrutamento',factory='Oficina Clandestina',lab='Entreposto',hospital='Posto de remendos',turret='Torre Improvisada',wall='Campo de barricadas',super='Oficina do Juízo Final',worker='Catador de sucata',rifle='Saqueador',scout='Batedor motociclista',heavy='Especialista em explosivos',sniper='Franco-atirador renegado',medic='Socorrista',engineer='Sabotador',buggy='Caminhonete técnica',tank='Caminhão blindado',elite='Incendiário',siege='Mech capturado',hero='John Pope',special='Chefe de saqueadores')
]
names[0].update(hero='Tom Mason',special='Ben Mason')
factions = [
 dict(name='Segunda Massachusetts',short='RESISTÊNCIA',motto='Resistir. Reconstruir. Retomar.',description='Tropas versáteis, cura superior e tecnologia recuperada.',hp=1.0,speed=1.0,cost=1.0,damage=1.0,weapon='Míssil Nuclear Recuperado',names=names[0]),
 dict(name='Forças Espheni',short='ESPHENI',motto='A Terra é apenas o começo.',description='Unidades resistentes e caras; máquinas de longo alcance.',hp=1.28,speed=.92,cost=1.25,damage=1.16,weapon='Bomba de Nêutrons',names=names[1]),
 dict(name='Berserkers de Pope',short='BERSERKERS',motto='Nada a perder. Tudo a tomar.',description='Mobilidade, recrutamento barato e suprimentos por abates.',hp=.86,speed=1.16,cost=.84,damage=1.08,weapon='Bomba Termobárica',names=names[2])
]
(ROOT/'data/content.json').write_text(json.dumps(dict(units=units,buildings=buildings,factions=factions),ensure_ascii=False,indent=2),encoding='utf-8')

# Timbres sintetizados matematicamente; nenhuma amostra externa.
out=ROOT/'assets/audio'; out.mkdir(parents=True,exist_ok=True)
def sound(name,duration,fn):
    rate=22050; rng=random.Random(91)
    with wave.open(str(out/(name+'.wav')),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed'))
        f.writeframes(b''.join(struct.pack('<h',int(max(-1,min(1,fn(i/rate,duration,rng)))*23000)) for i in range(int(rate*duration))))
sound('select',.10,lambda t,d,r: math.sin(t*math.tau*650)*.2*(1-t/d))
sound('order',.16,lambda t,d,r: math.sin(t*math.tau*(420 if t<.08 else 630))*.25*(1-t/d))
sound('shot',.12,lambda t,d,r: (r.random()*2-1)*math.exp(-t*38)*.42)
sound('blast',.8,lambda t,d,r: ((r.random()*2-1)*.6+math.sin(t*math.tau*48)*.4)*math.exp(-t*6))
sound('alert',.6,lambda t,d,r: math.sin(t*math.tau*(740 if int(t*10)%2 else 520))*.17)
sound('ready',.4,lambda t,d,r: math.sin(t*math.tau*(440 if t<.2 else 660))*.18*math.sin(math.pi*t/d))
sound('music',24,lambda t,d,r: (math.sin(math.tau*55*t)+.5*math.sin(math.tau*82.5*t)+.25*math.sin(math.tau*110*t))*.11*(.6+.4*math.sin(math.tau*t/12)**2)+math.sin(math.tau*[220,261.6256,293.6648,196][int(t/6)%4]*t)*.055*math.sin(math.pi*(t%6)/6)**2)
print('Dados e 7 sons originais gerados.')
