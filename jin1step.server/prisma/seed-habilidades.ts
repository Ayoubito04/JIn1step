//Catálogo inicial de habilidades. Sin estas filas la extracción no detecta nada,
//porque solo busca en el texto del CV lo que ya existe en la tabla Habilidad.
//
//Ejecutar con: npx ts-node --transpile-only prisma/seed-habilidades.ts
//Es idempotente: se puede lanzar las veces que haga falta.
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

const HABILIDADES = [
    //Lenguajes
    'JavaScript', 'TypeScript', 'Python', 'Java', 'C#', 'C++', 'PHP', 'Go',
    'Ruby', 'Kotlin', 'Swift', 'Rust', 'SQL',
    //Frontend
    'React', 'Vue.js', 'Angular', 'Next.js', 'HTML', 'CSS', 'Sass', 'Tailwind',
    'Redux', 'Svelte',
    //Backend
    'Node.js', 'Express', 'NestJS', 'Django', 'Flask', 'Spring', 'Laravel',
    '.NET', 'FastAPI',
    //Bases de datos
    'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'SQLite', 'Prisma', 'Oracle',
    //DevOps e infraestructura
    'Docker', 'Kubernetes', 'AWS', 'Azure', 'Google Cloud', 'Terraform',
    'Jenkins', 'Git', 'GitHub Actions', 'Linux', 'Nginx', 'CI/CD',
    //Datos
    'Pandas', 'NumPy', 'TensorFlow', 'PyTorch', 'Power BI', 'Tableau', 'Spark',
    //Móvil
    'React Native', 'Flutter', 'Android', 'iOS',
    //Testing
    'Jest', 'Cypress', 'Playwright', 'JUnit', 'Selenium',
    //Metodologías
    'Scrum', 'Agile', 'Kanban', 'TDD',
    //Idiomas
    'Inglés', 'Francés', 'Alemán', 'Árabe', 'Chino', 'Portugués',
    // Comercio, atención al cliente y retail
    'Atención al cliente', 'Ventas', 'Venta consultiva', 'Caja', 'Reposición',
    'Gestión de stock', 'Control de inventario', 'Visual merchandising',
    'Escaparatismo', 'Gestión de tienda', 'Resolución de incidencias',
    // Logística e industria
    'Logística', 'Preparación de pedidos', 'Picking', 'Packing',
    'Carretilla elevadora', 'Gestión de almacén', 'Cadena de suministro',
    'Conducción', 'Reparto', 'Manipulación de alimentos', 'Seguridad alimentaria',
    'Control de calidad', 'Mantenimiento', 'Soldadura', 'Electricidad',
    // Hostelería y servicios
    'Hostelería', 'Cocina', 'Camarero', 'Barista', 'Recepción hotelera',
    'Limpieza', 'Organización de eventos', 'Turismo',
    // Administración, finanzas y gestión
    'Administración', 'Contabilidad', 'Facturación', 'Nóminas', 'Excel',
    'Microsoft Office', 'Gestión documental', 'Compras', 'Gestión de proyectos',
    'Negociación', 'Comunicación', 'Trabajo en equipo', 'Organización',
    'Liderazgo', 'Resolución de problemas',
    // Salud, educación y cuidados
    'Enfermería', 'Atención sociosanitaria', 'Primeros auxilios', 'Farmacia',
    'Cuidados de personas mayores', 'Educación infantil', 'Docencia',
    // Marketing y contenido
    'Marketing digital', 'SEO', 'Redes sociales', 'Creación de contenido',
    'Diseño gráfico', 'Copywriting',
]

async function main() {
    const resultado = await prisma.habilidad.createMany({
        data: HABILIDADES.map((nombre) => ({ nombre })),
        skipDuplicates: true,
    })

    const total = await prisma.habilidad.count()

    console.log(`Insertadas ${resultado.count} habilidades nuevas.`)
    console.log(`Total en el catálogo: ${total}`)
}

main()
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
    .finally(() => prisma.$disconnect())
