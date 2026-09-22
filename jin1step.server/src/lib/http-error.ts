//Error con código HTTP, para poder responder 401/409 y no siempre 500
export class HttpError extends Error {
    constructor(
        public readonly statusCode: number,
        message: string,
    ) {
        super(message)
        this.name = 'HttpError'
    }
}
