module Geekstack
  # Official Chilean regions and comunas (346 comunas across the 16 regions
  # in force since the 2018 creation of Ñuble).
  #
  # We can't get this from Carmen/Spree::Seeds::States: Carmen only models
  # Chile at region level (15 regions — missing Ñuble entirely) and has no
  # comuna data at all, so it's useless for the zone/shipping granularity
  # this project needs (see app/models/spree/seeds/states_decorator.rb).
  # This is our own hand-maintained source of truth instead, seeded in
  # db/seeds.rb as one Spree::State per comuna with `region` set to its
  # parent region's name — the "padre" that flat Spree::State rows can't
  # otherwise express.
  #
  # Source: SUBDERE / INE division político-administrativa. Transcribed by
  # hand — worth a spot-check against an official list before relying on it
  # for anything beyond dev/shipping-zone purposes.
  module ChileRegions
    REGIONS = {
      "Arica y Parinacota" => %w[Arica Camarones Putre General\ Lagos],
      "Tarapacá" => %w[Iquique Alto\ Hospicio Pozo\ Almonte Camiña Colchane Huara Pica],
      "Antofagasta" => %w[Antofagasta Mejillones Sierra\ Gorda Taltal Calama Ollagüe San\ Pedro\ de\ Atacama Tocopilla María\ Elena],
      "Atacama" => %w[Copiapó Caldera Tierra\ Amarilla Chañaral Diego\ de\ Almagro Vallenar Alto\ del\ Carmen Freirina Huasco],
      "Coquimbo" => %w[La\ Serena Coquimbo Andacollo La\ Higuera Paiguano Vicuña Illapel Canela Los\ Vilos Salamanca Ovalle Combarbalá Monte\ Patria Punitaqui Río\ Hurtado],
      "Valparaíso" => %w[
        Valparaíso Casablanca Concón Juan\ Fernández Puchuncaví Quintero Viña\ del\ Mar
        Isla\ de\ Pascua
        Los\ Andes Calle\ Larga Rinconada San\ Esteban
        La\ Ligua Cabildo Papudo Petorca Zapallar
        Quillota La\ Calera Hijuelas La\ Cruz Nogales
        San\ Antonio Algarrobo Cartagena El\ Quisco El\ Tabo Santo\ Domingo
        San\ Felipe Catemu Llaillay Panquehue Putaendo Santa\ María
        Quilpué Limache Olmué Villa\ Alemana
      ],
      "Región Metropolitana de Santiago" => %w[
        Santiago Cerrillos Cerro\ Navia Conchalí El\ Bosque Estación\ Central Huechuraba
        Independencia La\ Cisterna La\ Florida La\ Granja La\ Pintana La\ Reina Las\ Condes
        Lo\ Barnechea Lo\ Espejo Lo\ Prado Macul Maipú Ñuñoa Pedro\ Aguirre\ Cerda Peñalolén
        Providencia Pudahuel Quilicura Quinta\ Normal Recoleta Renca San\ Joaquín San\ Miguel
        San\ Ramón Vitacura
        Puente\ Alto Pirque San\ José\ de\ Maipo
        Colina Lampa Tiltil
        San\ Bernardo Buin Calera\ de\ Tango Paine
        Melipilla Alhué Curacaví María\ Pinto San\ Pedro
        Talagante El\ Monte Isla\ de\ Maipo Padre\ Hurtado Peñaflor
      ],
      "Libertador General Bernardo O'Higgins" => %w[
        Rancagua Codegua Coinco Coltauco Doñihue Graneros Las\ Cabras Machalí Malloa
        Mostazal Olivar Peumo Pichidegua Quinta\ de\ Tilcoco Rengo Requínoa San\ Vicente
        Pichilemu La\ Estrella Litueche Marchihue Navidad Paredones
        San\ Fernando Chépica Chimbarongo Lolol Nancagua Palmilla Peralillo Placilla Pumanque Santa\ Cruz
      ],
      "Maule" => %w[
        Curicó Hualañé Licantén Molina Rauco Romeral Sagrada\ Familia Teno Vichuquén
        Talca Constitución Curepto Empedrado Maule Pelarco Pencahue Río\ Claro San\ Clemente San\ Rafael
        Linares Colbún Longaví Parral Retiro San\ Javier Villa\ Alegre Yerbas\ Buenas
        Cauquenes Chanco Pelluhue
      ],
      "Ñuble" => %w[
        Chillán Bulnes Chillán\ Viejo El\ Carmen Pemuco Pinto Quillón San\ Ignacio Yungay
        San\ Carlos Coihueco Ñiquén San\ Fabián San\ Nicolás
        Quirihue Cobquecura Coelemu Ninhue Portezuelo Ránquil Trehuaco
      ],
      "Biobío" => %w[
        Concepción Coronel Chiguayante Florida Hualqui Lota Penco San\ Pedro\ de\ la\ Paz
        Santa\ Juana Talcahuano Tomé Hualpén
        Lebu Arauco Cañete Contulmo Curanilahue Los\ Álamos Tirúa
        Los\ Ángeles Antuco Cabrero Laja Mulchén Nacimiento Negrete Quilaco Quilleco
        San\ Rosendo Santa\ Bárbara Tucapel Yumbel Alto\ Biobío
      ],
      "La Araucanía" => %w[
        Temuco Carahue Cholchol Cunco Curarrehue Freire Galvarino Gorbea Lautaro Loncoche
        Melipeuco Nueva\ Imperial Padre\ las\ Casas Perquenco Pitrufquén Pucón Saavedra
        Teodoro\ Schmidt Toltén Vilcún Villarrica
        Angol Collipulli Curacautín Ercilla Lonquimay Los\ Sauces Lumaco Purén Renaico Traiguén Victoria
      ],
      "Los Ríos" => %w[
        Valdivia Corral Lanco Los\ Lagos Máfil Mariquina Paillaco Panguipulli
        La\ Unión Futrono Lago\ Ranco Río\ Bueno
      ],
      "Los Lagos" => %w[
        Puerto\ Montt Calbuco Cochamó Fresia Frutillar Llanquihue Los\ Muermos Maullín Puerto\ Varas
        Castro Ancud Chonchi Curaco\ de\ Vélez Dalcahue Puqueldón Queilén Quellón Quemchi Quinchao
        Osorno Puerto\ Octay Purranque Puyehue Río\ Negro San\ Juan\ de\ la\ Costa San\ Pablo
        Chaitén Futaleufú Hualaihué Palena
      ],
      "Aysén del General Carlos Ibáñez del Campo" => %w[
        Coyhaique Lago\ Verde
        Aysén Cisnes Guaitecas
        Chile\ Chico Río\ Ibáñez
        Cochrane O'Higgins Tortel
      ],
      "Magallanes y de la Antártica Chilena" => %w[
        Punta\ Arenas Laguna\ Blanca Río\ Verde San\ Gregorio
        Natales Torres\ del\ Paine
        Porvenir Primavera Timaukel
        Cabo\ de\ Hornos Antártica
      ]
    }.freeze

    TOTAL_COMUNAS = REGIONS.values.sum(&:size)
  end
end
