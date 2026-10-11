// Catálogo inicial para facilitar la publicación de ofertas en España.
// Es idempotente: conserva los registros existentes y añade los que falten.
// Ejecutar desde jin1step.server: npx ts-node --transpile-only prisma/seed-empresas.ts
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

const EMPRESAS = [
    // Tecnología, telecomunicaciones y producto digital (primero en el selector)
    ['Telefónica', 'Tecnología y telecomunicaciones', 'Madrid', 'https://www.telefonica.com'],
    ['Indra', 'Tecnología y consultoría', 'Madrid', 'https://www.indracompany.com'],
    ['Minsait', 'Tecnología y consultoría', 'Madrid', 'https://www.minsait.com'],
    ['Amadeus', 'Tecnología y viajes', 'Madrid', 'https://amadeus.com'],
    ['Cabify', 'Tecnología y movilidad', 'Madrid', 'https://cabify.com'],
    ['Glovo', 'Tecnología y reparto', 'Barcelona', 'https://glovoapp.com'],
    ['Wallapop', 'Tecnología y comercio electrónico', 'Barcelona', 'https://www.wallapop.com'],
    ['TravelPerk', 'Tecnología y viajes', 'Barcelona', 'https://www.travelperk.com'],
    ['Typeform', 'Tecnología y software', 'Barcelona', 'https://www.typeform.com'],
    ['Factorial', 'Tecnología y software de RR. HH.', 'Barcelona', 'https://factorialhr.com'],
    ['Jobandtalent', 'Tecnología y empleo', 'Madrid', 'https://jobandtalent.com'],
    ['eDreams ODIGEO', 'Tecnología y viajes', 'Barcelona', 'https://www.edreamsodigeo.com'],
    ['PcComponentes', 'Tecnología y comercio electrónico', 'Alhama de Murcia', 'https://www.pccomponentes.com'],
    ['Sngular', 'Tecnología y consultoría', 'Madrid', 'https://www.sngular.com'],
    ['Multiverse Computing', 'Tecnología e inteligencia artificial', 'San Sebastián', 'https://multiversecomputing.com'],
    ['Devo', 'Tecnología y ciberseguridad', 'Madrid', 'https://www.devo.com'],
    ['Clarity AI', 'Tecnología y sostenibilidad', 'Madrid', 'https://clarity.ai'],
    ['SeQura', 'Tecnología financiera', 'Barcelona', 'https://www.sequra.com'],
    ['Carto', 'Tecnología y datos geoespaciales', 'Madrid', 'https://carto.com'],
    ['Bdeo', 'Tecnología y seguros', 'Madrid', 'https://bdeo.io'],
    ['Fever', 'Tecnología y entretenimiento', 'Madrid', 'https://feverup.com'],
    ['Adevinta', 'Tecnología y anuncios clasificados', 'Barcelona', 'https://www.adevinta.com'],
    ['GMV', 'Tecnología e ingeniería', 'Tres Cantos', 'https://www.gmv.com'],
    ['SENER', 'Tecnología e ingeniería', 'Getxo', 'https://www.group.sener'],
    ['NTT DATA España', 'Tecnología y consultoría', 'Madrid', 'https://es.nttdata.com'],
    ['Ayesa', 'Tecnología e ingeniería', 'Sevilla', 'https://www.ayesa.com'],
    ['Izertis', 'Tecnología y consultoría', 'Gijón', 'https://www.izertis.com'],
    ['Seidor', 'Tecnología y consultoría', 'Barcelona', 'https://www.seidor.com'],
    ['Plain Concepts', 'Tecnología y software', 'Madrid', 'https://www.plainconcepts.com'],
    ['GFT', 'Tecnología y consultoría', 'Sant Cugat del Vallès', 'https://www.gft.com/es/es'],
    ['Sopra Steria España', 'Tecnología y consultoría', 'Madrid', 'https://www.soprasteria.es'],
    ['Inetum España', 'Tecnología y consultoría', 'Madrid', 'https://www.inetum.com/es'],
    ['Accenture España', 'Tecnología y consultoría', 'Madrid', 'https://www.accenture.com/es-es'],
    ['Deloitte España', 'Tecnología y consultoría', 'Madrid', 'https://www.deloitte.com/es/es.html'],
    ['Telefónica Tech', 'Tecnología y ciberseguridad', 'Madrid', 'https://telefonicatech.com'],
    ['Orange España', 'Tecnología y telecomunicaciones', 'Madrid', 'https://www.orange.es'],
    ['Vodafone España', 'Tecnología y telecomunicaciones', 'Madrid', 'https://www.vodafone.es'],
    ['MasOrange', 'Tecnología y telecomunicaciones', 'Madrid', 'https://www.masorange.es'],
    ['Siemens España', 'Tecnología e industria', 'Madrid', 'https://www.siemens.com/es/es.html'],
    ['Bosch España', 'Tecnología e industria', 'Madrid', 'https://www.bosch.es'],
    ['HP España', 'Tecnología', 'Sant Cugat del Vallès', 'https://www.hp.com/es-es'],
    ['Google España', 'Tecnología', 'Madrid', 'https://careers.google.com'],
    ['Microsoft España', 'Tecnología', 'Madrid', 'https://careers.microsoft.com'],
    ['Amazon España', 'Tecnología y comercio electrónico', 'Madrid', 'https://www.amazon.jobs'],
    // Distribución, alimentación y comercio
    ['ALDI', 'Alimentación y distribución', 'Barcelona', 'https://www.aldi.es'],
    ['Mercadona', 'Alimentación y distribución', 'Tavernes Blanques', 'https://www.mercadona.es'],
    ['Consum', 'Alimentación y distribución', 'Silla', 'https://www.consum.es'],
    ['Lidl', 'Alimentación y distribución', 'Montcada i Reixac', 'https://empleo.lidl.es'],
    ['Carrefour', 'Alimentación y distribución', 'Madrid', 'https://www.carrefour.es'],
    ['DIA', 'Alimentación y distribución', 'Las Rozas', 'https://www.dia.es'],
    ['Eroski', 'Alimentación y distribución', 'Elorrio', 'https://www.eroski.es'],
    ['El Corte Inglés', 'Comercio y distribución', 'Madrid', 'https://www.elcorteingles.es'],
    ['Alcampo', 'Comercio y distribución', 'Madrid', 'https://www.alcampo.es'],
    ['Inditex', 'Moda y comercio', 'Arteixo', 'https://www.inditex.com'],
    ['Mango', 'Moda y comercio', 'Palau-solità i Plegamans', 'https://www.mango.com'],
    // Otros sectores
    ['Santander', 'Banca y finanzas', 'Santander', 'https://www.santander.com'],
    ['BBVA', 'Banca y finanzas', 'Bilbao', 'https://www.bbva.com'],
    ['CaixaBank', 'Banca y finanzas', 'Valencia', 'https://www.caixabank.com'],
    ['Iberdrola', 'Energía', 'Bilbao', 'https://www.iberdrola.com'],
    ['Repsol', 'Energía', 'Madrid', 'https://www.repsol.com'],
    ['Renfe', 'Transporte ferroviario', 'Madrid', 'https://www.renfe.com'],
    ['Iberia', 'Transporte aéreo', 'Madrid', 'https://www.iberia.com'],
    ['Correos', 'Logística y transporte', 'Madrid', 'https://www.correos.com'],
    ['SEUR', 'Logística y transporte', 'Madrid', 'https://www.seur.com'],
    ['Meliá Hotels International', 'Turismo y hostelería', 'Palma', 'https://www.meliahotelsinternational.com'],
    ['Sanitas', 'Salud', 'Madrid', 'https://www.sanitas.es'],
    ['Quirónsalud', 'Salud', 'Madrid', 'https://www.quironsalud.com'],
] as const

async function main() {
    let insertadas = 0
    for (const [nombre, sector, ubicacion, sitioWeb] of EMPRESAS) {
        const existente = await prisma.empresa.findFirst({ where: { nombre } })
        if (existente) continue
        await prisma.empresa.create({ data: { nombre, sector, ubicacion, sitioWeb } })
        insertadas++
    }
    console.log(`Insertadas ${insertadas} empresas nuevas (de ${EMPRESAS.length} sugeridas).`)
}

main().catch((error) => { console.error(error); process.exit(1) }).finally(() => prisma.$disconnect())
