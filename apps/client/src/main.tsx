import {
  QueryClient,
  QueryClientProvider,
  queryOptions,
  useQuery,
} from '@tanstack/react-query';
import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Link,
  Outlet,
  RouterProvider,
} from '@tanstack/react-router';
import {useState} from 'react';
import {createRoot} from 'react-dom/client';

import {TeamGraph} from './team-graph';
import './theme.css';

const fixtureProject = queryOptions({
  queryKey: ['fixture', 'project'],
  queryFn: () => ({
    title: 'Observatory',
    sessions: [
      {
        id: 'fixture-session',
        name: 'Shell verification',
        detail: '',
        status: 'Standby' as const,
      },
    ],
  }),
  staleTime: Infinity,
});

function Workspace() {
  const project = useQuery(fixtureProject);
  if (!project.data) return <p>Loading fixture…</p>;
  return (
    <section aria-labelledby="workspace-heading">
      <h2 id="workspace-heading">Synthetic workspace</h2>
      <Link className="project" to="/project">
        {project.data.title}
      </Link>
    </section>
  );
}

function Project() {
  const [selectedId, select] = useState<string>();
  const [expanded, setExpanded] = useState(false);
  const project = useQuery(fixtureProject);
  if (!project.data) return <p>Loading fixture…</p>;
  return (
    <section aria-labelledby="project-heading">
      <Link to="/">All projects</Link>
      <h2 id="project-heading">{project.data.title}</h2>
      <button aria-expanded={expanded} onClick={() => setExpanded(!expanded)}>
        Sessions
      </button>
      {expanded && (
        <TeamGraph
          cards={project.data.sessions}
          {...(selectedId === undefined ? {} : {selectedId})}
          onSelect={select}
        />
      )}
    </section>
  );
}

const root = createRootRoute({
  component: () => (
    <main>
      <h1>J.A.R.V.I.S.</h1>
      <Outlet />
    </main>
  ),
});
const home = createRoute({
  getParentRoute: () => root,
  path: '/',
  component: Workspace,
});
const project = createRoute({
  getParentRoute: () => root,
  path: 'project',
  component: Project,
});
const router = createRouter({
  routeTree: root.addChildren([home, project]),
  history: createMemoryHistory({initialEntries: ['/']}),
});
declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
const queries = new QueryClient({defaultOptions: {queries: {retry: false}}});
const container = document.getElementById('root');
if (!container) throw new Error('Missing renderer entry point');
createRoot(container).render(
  <QueryClientProvider client={queries}>
    <RouterProvider router={router} />
  </QueryClientProvider>,
);
