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

  //Las claves de Stripe NO usan required(): el servidor tiene que poder
  //arrancar sin ellas para desarrollar el resto de modulos. Quien las
  //necesita comprueba que existan y devuelve 503 si faltan, en vez de
  //tumbar todo el backend por no poder cobrar.
  stripeSecretKey: process.env.STRIPE_SECRET_KEY ?? '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET ?? '',
  //El precio se define en Stripe, no aqui: alli es donde se cambia sin
  //tocar codigo. Estos son los ids de cada plan (price_...).
  stripePriceMensual: process.env.STRIPE_PRICE_MENSUAL ?? '',
  stripePriceAnual: process.env.STRIPE_PRICE_ANUAL ?? '',
  //A donde vuelve el usuario tras pagar o cancelar en el checkout.
  appUrl: process.env.APP_URL ?? 'http://localhost:3000',
  
};