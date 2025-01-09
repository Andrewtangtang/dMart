import { GraphQLScalarType, Kind } from 'graphql';

const DateTime = new GraphQLScalarType({
    name: 'DateTime',
    description: 'DateTime custom scalar type',
    async serialize(value) {
      if (value instanceof Date) {
        return value.getTime(); // Convert outgoing Date to integer for JSON
      }
      throw Error('GraphQL Date Scalar serializer expected a Date object');
    },
    async parseValue(value) {
      if (typeof value === 'number') {
        return new Date(value); // Convert incoming integer to Date
      }
      throw new Error('GraphQL Date Scalar parser expected a number');
    },
    async parseLiteral(ast) {
      if (ast.kind === Kind.INT) {
        // Convert hard-coded AST string to integer and then to Date
        return new Date(parseInt(ast.value, 10));
      }
      // Invalid hard-coded value (not an integer)
      return null;
    },
});
  
const typeDefs = `#graphql
  # Comments in GraphQL strings (such as this one) start with the hash (#) symbol.

  ### Define Data Structure ###
  
  scalar DateTime

  input UserInput {
    address: String!
  }

  input ProjectInput {
    creator: User!
    target: Int!
    title: String!
    description: String!
    photoLink: String!
    ipfs: String!
  }

  input ProjectUpdateInput {
    phase: Int!
    success: Boolean!
    end: Boolean!
  }

  
  type User {
    id: Int!
    address: String!
  }

  type Project {
    creator: User!
    donators: [Users]!
    target: Int!
    fund: Int!
    title: String!
    description: String!
    photoLink: String!
    ipfs: String!
    date: String!
    phase: Int!
    success: Boolean!
    end: Boolean!
  }

  ### Define Resolvers ###
  
  type Query {
    AllProjects: [Project]
  }

  type Mutation {
    AddUser(userInput: UserInput): User
    AddProject(projectInput: ProjectInput): Project
    ProjectUpdate(projectUpdateInput: ProjectUpdateInput): Project
  }

  type Subscritpion {
    UserCreated: User
    ProjectCreated: Project
    ProjectUpdated: Project
  }
`;

export { typeDefs, DateTime }