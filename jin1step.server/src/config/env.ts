//Aquí vamos a configurar las distintas variables de entorno
import  'dotenv/config'


function required(name:string):string{
    const value=process.env[name]
    if(!value){
      throw new Error(
         `Falta la variable de entorno ${name}. Revisa tu archivo .env`
      );

}
  return value;
}
export const env={
    port: Number(process.env.PORT ?? 3000),
    nodeEnv: process.env.NODE_ENV ?? 'development',
  isProduction: process.env.NODE_ENV === 'production',

  databaseUrl: required('DATABASE_URL'),
  jwtSecret: required('JWT_SECRET'),
  jwtRefreshSecret: required('JWT_REFRESH_SECRET'),

  googleClientId: process.env.GOOGLE_CLIENT_ID ?? '',
  
};