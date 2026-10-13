require('dotenv/config')

const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()

const TEMPLATE_MARKER = 'AUTOPILOT-2026'
const focusByNumber = [
  'plataforma de pagos', 'producto digital', 'servicios cloud', 'analítica de datos',
  'aplicaciones móviles', 'comercio electrónico', 'automatización', 'ciberseguridad',
  'experiencia de usuario', 'integraciones',
]

async function main() {
  if (process.env.NODE_ENV === 'production') {
    throw new Error('Este script solo se puede ejecutar en desarrollo.')
  }
  const database = new URL(process.env.DATABASE_URL)
  if (!['localhost', '127.0.0.1'].includes(database.hostname) || database.pathname !== '/jin1step_db') {
    throw new Error('Se canceló: DATABASE_URL no apunta a la base local jin1step_db.')
  }

  const numbered = await prisma.oferta.findMany({
    where: { titulo: { startsWith: 'Desarrollador/a #' } },
    include: { requisitos: true },
  })
  const placeholders = numbered
    .map((offer) => ({ offer, number: Number(offer.titulo.match(/#(\d+)$/)?.[1]) }))
    .filter(({ number }) => Number.isInteger(number))
    .sort((a, b) => a.number - b.number)
  if (placeholders.length === 0) {
    console.log('No quedan ofertas Desarrollador/a #N que actualizar.')
    return
  }

  const demoOwner = await prisma.usuario.findUnique({ where: { email: 'demo.autopilot@jin1step.local' } })
  if (!demoOwner) throw new Error('No se encuentra el conjunto local de ofertas de demostración.')
  const templates = await prisma.oferta.findMany({
    where: { reclutadorId: demoOwner.id, descripcion: { contains: TEMPLATE_MARKER } },
    include: { requisitos: true },
    orderBy: [{ titulo: 'asc' }, { empresaId: 'asc' }],
  })
  if (templates.length < placeholders.length) {
    throw new Error(`Hay ${placeholders.length} ofertas numeradas pero solo ${templates.length} plantillas.`)
  }
  const habilidades = await prisma.habilidad.findMany()
  const nombrePorId = new Map(habilidades.map((skill) => [skill.id, skill.nombre]))

  await prisma.$transaction(async (tx) => {
    for (let index = 0; index < placeholders.length; index += 1) {
      const { offer, number } = placeholders[index]
      const template = templates[index]
      const title = `${template.titulo} · ${focusByNumber[(number - 1) % focusByNumber.length]}`
      const templateSkills = template.requisitos
        .map((requirement) => ({
          nombre: nombrePorId.get(requirement.habilidadId),
          obligatorio: requirement.obligatorio,
        }))
        .filter((requirement) => requirement.nombre)

      await tx.ofertaRequisito.deleteMany({ where: { ofertaId: offer.id } })
      await tx.oferta.update({
        where: { id: offer.id },
        data: {
          empresaId: template.empresaId,
          titulo: title,
          descripcion: `${template.descripcion}\n\nEnfoque del puesto: ${focusByNumber[(number - 1) % focusByNumber.length]}. Vacante ficticia de demostración para el portafolio Jin1step.`,
          modalidad: template.modalidad,
          requisitos: {
            create: templateSkills.map((requirement) => ({
              habilidadId: habilidades.find((skill) => skill.nombre === requirement.nombre).id,
              obligatorio: requirement.obligatorio,
            })),
          },
        },
      })
    }
  }, { maxWait: 20000, timeout: 120000 })

  const updated = await prisma.oferta.findMany({
    where: { id: { in: placeholders.map(({ offer }) => offer.id) } },
    select: {
      titulo: true,
      requisitos: { select: { habilidad: { select: { nombre: true } }, obligatorio: true } },
      _count: { select: { postulaciones: true } },
    },
  })
  console.log(JSON.stringify({
    actualizadas: updated.length,
    ofertasConRequisitos: updated.filter((offer) => offer.requisitos.length >= 5).length,
    candidaturasConservadas: updated.reduce((sum, offer) => sum + offer._count.postulaciones, 0),
    ejemplos: updated.slice(0, 5).map((offer) => ({
      titulo: offer.titulo,
      requisitos: offer.requisitos.map((requirement) => requirement.habilidad.nombre),
      candidaturas: offer._count.postulaciones,
    })),
  }, null, 2))
}

main().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
}).finally(async () => prisma.$disconnect())
