require('dotenv/config')

const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

const MARKER = 'Vacante ficticia de demostración Jin1step AUTOPILOT-2026.'
const OWNER_EMAIL = 'demo.autopilot@jin1step.local'

const companies = [
  { name: 'NorteByte Demo', location: 'Bilbao', sector: 'Software empresarial' },
  { name: 'PixelForge Demo', location: 'Barcelona', sector: 'Producto digital' },
  { name: 'LumenStack Demo', location: 'Madrid', sector: 'Cloud y plataformas' },
  { name: 'DataLoom Demo', location: 'Valencia', sector: 'Datos e inteligencia de negocio' },
  { name: 'Marea Digital Demo', location: 'Málaga', sector: 'Tecnología aplicada' },
  { name: 'Kernelia Demo', location: 'Zaragoza', sector: 'Infraestructura de software' },
  { name: 'Brava Labs Demo', location: 'Sevilla', sector: 'Fintech de demostración' },
  { name: 'AtlasNube Demo', location: 'A Coruña', sector: 'Servicios cloud' },
  { name: 'Vértice Código Demo', location: 'Alicante', sector: 'Consultoría tecnológica' },
  { name: 'RobleTech Demo', location: 'Valladolid', sector: 'Automatización de procesos' },
]

const roles = [
  { title: 'Desarrollador/a Backend Java', skills: ['Java', 'Spring Boot', 'PostgreSQL', 'API REST', 'Git'], base: 28000 },
  { title: 'Desarrollador/a Backend Node.js', skills: ['Node.js', 'TypeScript', 'NestJS', 'PostgreSQL', 'Docker'], base: 27000 },
  { title: 'Desarrollador/a Flutter', skills: ['Dart', 'Flutter', 'API REST', 'Git', 'Firebase'], base: 26000 },
  { title: 'Desarrollador/a Frontend React', skills: ['JavaScript', 'React', 'TypeScript', 'HTML', 'CSS'], base: 25000 },
  { title: 'Desarrollador/a Full Stack', skills: ['React', 'Node.js', 'TypeScript', 'PostgreSQL', 'Docker'], base: 29000 },
  { title: 'Desarrollador/a Python', skills: ['Python', 'Django', 'PostgreSQL', 'API REST', 'Docker'], base: 27000 },
  { title: 'Ingeniero/a DevOps', skills: ['Linux', 'Docker', 'Kubernetes', 'AWS', 'CI/CD'], base: 32000 },
  { title: 'Desarrollador/a de datos', skills: ['Python', 'SQL', 'Apache Spark', 'Apache Airflow', 'AWS'], base: 30000 },
  { title: 'QA Automation Engineer', skills: ['QA Automation', 'Selenium', 'Cypress', 'Java', 'Git'], base: 25000 },
  { title: 'Software Engineer Go y Cloud', skills: ['Go', 'Kubernetes', 'Terraform', 'AWS', 'Linux'], base: 33000 },
]

const levels = [
  'Junior', 'Junior con experiencia', 'Mid-level', 'Mid-level', 'Semi Senior',
  'Senior', 'Senior', 'Lead', 'Staff', 'Tech Lead',
]
const modes = ['HIBRIDO', 'REMOTO', 'PRESENCIAL', 'HIBRIDO', 'REMOTO']
const initiatives = [
  'modernizar servicios y mejorar su observabilidad',
  'desarrollar nuevas funcionalidades para una plataforma de clientes',
  'mejorar la calidad, seguridad y rendimiento de los despliegues',
  'evolucionar una arquitectura modular junto a producto y diseño',
  'automatizar procesos y reducir tareas manuales del equipo',
]

function annualSalary(base, level) {
  const low = base + level * 2500
  const high = low + 5000
  return `${low.toLocaleString('es-ES')}–${high.toLocaleString('es-ES')} € brutos/año`
}

async function main() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Este conjunto de datos solo se puede cargar en desarrollo.')
  }
  const database = new URL(process.env.DATABASE_URL)
  if (!['localhost', '127.0.0.1'].includes(database.hostname) || database.pathname !== '/jin1step_db') {
    throw new Error('Se canceló: DATABASE_URL no apunta a la base local jin1step_db.')
  }

  let owner = await prisma.usuario.findUnique({ where: { email: OWNER_EMAIL } })
  const alreadySeeded = owner
    ? await prisma.oferta.count({
        where: { reclutadorId: owner.id, descripcion: { contains: MARKER } },
      })
    : 0
  if (alreadySeeded === 100) {
    const existentes = await prisma.oferta.findMany({
      where: { reclutadorId: owner.id, descripcion: { contains: MARKER } },
      select: { _count: { select: { requisitos: true } } },
    })
    const ofertasConCincoRequisitos = existentes.filter(
      (oferta) => oferta._count.requisitos === 5,
    ).length
    console.log(
      `Verificado: ${existentes.length} ofertas de demostración, ` +
        `${ofertasConCincoRequisitos} con cinco requisitos; no se duplicó nada.`,
    )
    return
  }
  if (alreadySeeded > 0) {
    throw new Error(`Se encontraron ${alreadySeeded} ofertas previas del conjunto. No se modificaron.`)
  }

  owner ??= await prisma.usuario.create({
    data: {
      nombre: 'Reclutador',
      apellidos: 'Demo Jin1step',
      email: OWNER_EMAIL,
      rol: 'RECLUTADOR',
    },
  })

  const companyRecords = []
  for (const company of companies) {
    let record = await prisma.empresa.findFirst({ where: { nombre: company.name } })
    record ??= await prisma.empresa.create({
      data: { nombre: company.name, ubicacion: company.location, sector: company.sector },
    })
    companyRecords.push(record)
  }

  const allSkillNames = [...new Set(roles.flatMap((role) => role.skills))]
  const currentSkills = await prisma.habilidad.findMany()
  const skillByName = new Map(
    currentSkills.map((skill) => [skill.nombre.trim().toLocaleLowerCase('es'), skill]),
  )
  for (const name of allSkillNames) {
    const normalized = name.trim().toLocaleLowerCase('es')
    if (!skillByName.has(normalized)) {
      const skill = await prisma.habilidad.create({ data: { nombre: name } })
      skillByName.set(normalized, skill)
    }
  }

  const seniority = levels.map((level) => `nivel ${level.toLowerCase()}`)
  const ofertas = []
  for (let roleIndex = 0; roleIndex < roles.length; roleIndex += 1) {
    const role = roles[roleIndex]
    for (let levelIndex = 0; levelIndex < levels.length; levelIndex += 1) {
      const companyIndex = (roleIndex * 3 + levelIndex) % companies.length
      const company = companies[companyIndex]
      const initiative = initiatives[(roleIndex + levelIndex) % initiatives.length]
      const mode = modes[(roleIndex + levelIndex) % modes.length]
      const place = mode === 'REMOTO' ? 'España (remoto)' : company.location
      const salary = annualSalary(role.base, levelIndex)
      const skills = role.skills.map((name) => skillByName.get(name.toLocaleLowerCase('es')))

      ofertas.push({
        empresaId: companyRecords[companyIndex].id,
        reclutadorId: owner.id,
        titulo: `${role.title} — ${levels[levelIndex]}`,
        descripcion: [
          `En ${company.name} buscamos un/a profesional ${seniority[levelIndex]} para ${initiative}.`,
          `Trabajarás con un equipo multidisciplinar, participarás en revisiones de código y colaborarás en decisiones técnicas y de producto.`,
          `Modalidad: ${mode.toLowerCase()}. Ubicación: ${place}. Banda orientativa: ${salary}.`,
          'Valoramos la comunicación, la autonomía y el interés por mantener software fiable y fácil de evolucionar.',
          MARKER,
        ].join('\n\n'),
        modalidad: mode,
        requisitos: {
          create: skills.map((skill, skillIndex) => ({
            habilidadId: skill.id,
            obligatorio: skillIndex < 3,
          })),
        },
      })
    }
  }

  await prisma.$transaction(
    async (tx) => {
      for (const oferta of ofertas) {
        const { requisitos, ...data } = oferta
        await tx.oferta.create({ data: { ...data, requisitos } })
      }
    },
    { maxWait: 20000, timeout: 120000 },
  )

  console.log(`Creadas ${ofertas.length} ofertas de desarrollador con cinco requisitos cada una.`)
  console.log(`Empresas ficticias de demostración: ${companies.length}; bandas salariales y ubicaciones incluidas.`)
}

main()
  .catch((error) => {
    console.error(error.message)
    process.exitCode = 1
  })
  .finally(async () => prisma.$disconnect())
